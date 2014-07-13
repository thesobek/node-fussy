# standard node library
fs     = require 'fs'
path   = require 'path'
util   = require 'util'
Url    = require 'url'



# thrid party modules
Lazy    = require 'lazy.js'
unzip   = require 'unzip'
mime    = require 'mime'
colors  = require 'colors'
#csv     = require 'csv-stream'
csv     = require 'ya-csv'

#streamBuffers = require 'stream-buffers'
#duplexify = require 'duplexify'

# our modules
utils   = require './utils'
extract = require './extract'
pretty = utils.pretty
debug = (x) -> console.log x



class Fussy

  constructor: (@input) ->
    #toolbox:
    @pretty = utils.pretty
    @pperf = utils.pperf
    @pstats = utils.pstats


  _parse: (data) ->
    debug "    .parse(data)" +"  // convert raw chunk into full featured object".grey
    #debug input
    output = undefined
    #debug "map: extracting features from "+JSON.stringify input

    # do we have a schema defined?
    if flow.schema?
      if utils.isString data
        #debug "trying to parse csv line using schema"
        #debug "line: "+input
        try
          output = utils.parse flow.schema, data
        catch exc
          #debug exc
          debug "couldn't parse line, trying to parse json from string"
          try
            output = JSON.parse data
          catch exc
            #debug exc
            debug "couldn't parse json. I could use the object as is, but since you defined a schema I prefer to skip it"
            output = undefined
      else
        output = data

    else if utils.isString data
      debug "no schema, trying to parse json from string"
      output = JSON.parse data
    else
      debug "no schema, using js object as-is"
      output = data
    debug "#{pretty input} =====> #{pretty output}"
    #debug "extracting output"
    output

  _extract: (event, facts=[], prefix="") ->

    #console.log "extracting features from: #{JSON.stringify event}"
    ###
    This was supposed to be a built-in support for a "date" attribute
    TODO but it is a bit awkward: we should rather use the schema for that.
    let's disable it for now.
    ###
    #if facts.length is 0
    #  if event.date?
    #    facts.push ['Date', 'date', moment(event.date).format()]
    #    delete event['date']

    try
      for key, value of event

        key = prefix + key
        #console.log "key: #{key}"

        # TODO we should use in priority the schema for this, then only detect type
        # as a fallback

        if utils.isString value
          #console.log "String"
          facts.push ['String', key, value]

        else if utils.isArray value
          #console.log "Array"
          facts.push ['Array', key, value]

        else if utils.isNumber value
          #console.log "Number"
          facts.push ['Number', key, value]

        else if utils.isBoolean value
          #console.log "Boolean"
          facts.push ['Boolean', key, value]

        else
          #console.log "recursive"
          @_extract value, facts, key + "." # recursively flatten nested features
    catch exc
      console.log "failed: "+exc
      console.log exc

    #console.log "facts: " + JSON.stringify facts
    facts

  schema: (schema) ->
    @_schema = schema
    @

  query: (query) ->
    debug "query"

    onError: (cb) ->
      err = "unknow error"
      cb err
    onComplete: (cb) ->
      debug "onComplete"
      result = {}
      cb result


  _pipeline: (input) ->
    parsed = @_parse input
    extracted = @_extract parsed
    extracted

module.exports =

  database: (input) ->
    new Fussy input

  # construct a fussy stream from a lazy stream
Fussy.lazy = (input) ->
  debug "\n  // calling Fussy.lazy(..) behind the hood".grey
  unless input.async?
    throw "error, input cannot be made asynchronous"
  flow =
    schema: undefined
    input: input#.async()

  # let's wrap around some of Lazy's functions
  #funcs = ['drop','take']
  #for f in funcs
  #  do (flow,f) -> flow[f] = ->
  #    flow.stream = flow.stream[f] arguments...
  #    flow

  flow.parse = (schema) ->
    debug "  .parse(\"#{schema}\")" + " // loading schema".grey
    try
      flow.schema = utils.loadSchema schema
    catch exc
      debug "couldn't read schema: #{exc}"
      flow.schema = undefined

    flow

  flow.drop = (n) ->
    flow.input = flow.input.drop n
    flow

  flow.take = (n) ->
    flow.input = flow.input.take n
    flow

  flow.rest = (n) ->
    flow.input = flow.input.rest n
    flow

  flow.shuffle = ->
    flow.input = flow.input.shuffle()
    flow

  flow.where = (properties) ->
    flow.input = flow.input.where(properties)
    flow

  flow.sortBy = (sortFn) ->
    flow.input = flow.input.sortBy(sortFn)

  flow.query = (query) ->

    debug "  .query()" + "      // preparing the rabbit".grey
    #debug "prepare query: "+pretty query

    if query.select?

      if utils.isString query.select
        tmp = {}
        tmp[query.select] = []
        query.select = tmp

      else if utils.isArray query.select
        tmp = {}
        for select in query.select
          tmp[select] = []
        query.select = tmp

      # else we assume this is a correctly formatted object


    unless utils.isArray query.where
      query.where = [ query.where ]



      # reduce
    reduceFn = (aggregated, features) ->
      debug "    .reduceFn()" +" // deep comparison".grey
      #debug "aggregated: " + pretty aggregated
      #debug "features: "+pretty features

      weight = 0
      factors = []

      nb_feats = 0
      #debug "query.where: "+pretty where

      for where in query.where
        #debug "where: " + pretty where
        depth = 0
        complexity = 0

        for [type, key, value] in features

          #debug [type, key, value]

          if key of where

            whereValues = if utils.isArray where[key]
                where[key]
              else
                [where[key]]

            match = no

            for whereValue in whereValues

              switch type
                when 'String'
                  value = "#{value}"
                  whereValue = "#{whereValue}"
                  if ' ' in value or ' ' in whereValue
                    [_depth,_nb_feats] = text.distance value, whereValue
                    depth += _depth
                    nb_feats += _nb_feats
                    match = yes
                  else
                    if value is whereValue
                      depth += 1
                      match = yes

                when 'Number'
                  whereValue = (Number) whereValue
                  if !isNaN(whereValue) and isFinite(whereValue)
                    delta = Math.abs value - whereValue
                    # bad performance if we use 2/1 on sonar dataset
                    depth += 1 / (1 + delta)
                    match = yes


                when 'Boolean'
                  if ((Boolean) value) is ((Boolean) whereValue)
                    depth += 1
                    match = yes

                else
                  debug "type #{type} not supported"

            if match
              nb_feats += 1

        # these parameters depends on the plateform
        depth *= Math.min 6, 300 / nb_feats
        weight += 10 ** Math.min 300, depth

      for [type, key, value] in features
        #debug "key: "+key

        if query.select?
          unless key of query.select
            continue

        #debug "here"
        unless key of aggregated.types
          aggregated.types[key] = type

        # TODO put the 4 following lines before the "continue unless"
        # if you want to catch all results
        unless key of aggregated.result
          aggregated.result[key] = {}

        unless value of aggregated.result[key]
          aggregated.result[key][value] = 0


        #debug "match for #{key}: #{query.select[key]}"

        match = no
        if utils.isArray query.select[key]
          #debug "array"
          if query.select[key].length
            if value in query.select[key]
              #debug "SELECT match in array!"
              match = yes
          else
            #debug "empty"
            match = yes
        else
          #debug "not array"
          if value is query.select[key]
            #debug "SELECT match single value!"
            match = yes

        if match
          aggregated.result[key][value] += weight

      debug "generated aggregated result"
      #debug pretty aggregated
      aggregated

      #.tap -> debug("reduce: computing prediction")


    all = ->
      debug "  .all()"+"        // calling blocking reduce() function".grey

      onComplete: (cb) ->

        debug ".onComplete()"

        flow.input
          .toArray()
          .onError (error) ->
            console.log "    .onError()"
            console.log error
            console.trace()
          .onComplete (arr) ->

            debug "    .onComplete()"

            debug "initializing"
            {result, types} = Lazy(arr)
              .map(parseFn)
              .compact()
              .reduce(reduceFn, {result: {}, types: {}})

            debug "result: " + pretty result

            sortFn = (input) ->
              debug "    .sortFn()"+" // sort options by probability".grey
              output = input.sort (a,b) -> b[2] - a[2]
              output

            # convert a key:{ opt_a:3, opt_b: 4}
            castFn = (input) ->
              debug "    .castFn()"+"  // cast output map to typed array"
              [key, options] = input
              if types[key] is 'Number'
                for option, weight of options
                  [key, (Number) option, weight]
              else if types[key] is 'Boolean'
                for option, weight of options
                  [key, (Boolean) option, weight]
              else
                for option, weight of options
                  [key, option, weight]

            console.log "third lazy: for results"
            res = Lazy(result)
              .pairs()     # convert the map or keys to array of keys
              .map(castFn) # convert the map of options to array of options
              .map(sortFn) # sort by weight
              .toArray()
          cb res

      undefined


    best = ->
      debug "best"
      {result, types} = flow.output
        .reduce(reduceFn, {result: {}, types: {}})

      Lazy(reduced.result).pairs().map (input) ->
        [key, options] = input
        output = []
        for option, weight of options
          if reduced.types[key] is 'Number'
            option = (Number) option
          else if reduced.types[key] is 'Boolean'
            option = (Boolean) option
          output.push [option, weight]
        output.sort (a,b) -> b[1] - a[1]

        # keep only the best
        output = output[0][0]

      Lazy result


    mix = ->
      debug "mix"
      {result, types} = flow.output
        .reduce(reduceFn, {result: {}, types: {}})

      result = {}
      for key, options of reduced.result
        isNumerical = reduced.types[key] is 'Number'

        if utils.isNumerical

          sum = 0
          for option, weight of options
            sum += weight

          result[key] = 0
          for option, weight of options
            option = (Number) option
            result[key] += option * (weight / sum)

        else
          result[key] = []
          for option, weight of options
            if reduced.types[key] is 'Boolean'
              option = (Boolean) option
            result[key].push [option, weight]
          result[key].sort (a,b) -> b[1] - a[1]
          best = result[key][0] # get the best
          result[key] = best[0] # get the value

      Lazy result

    {all, best, mix}

  flow

# mongo stream
Fussy.mongo = (input) ->
  if !input? or input is ''
    throw new Error 'Empty or null input'
  throw new Error "Not Implemented"

Fussy.sequence = (input) ->
  if !input? or input is ''
    throw new Error 'Empty or null input'
  lazy = Lazy(input)
  Fussy.lazy lazy

Fussy.file = (input) ->
  if !input? or input is ''
    throw new Error 'Empty or null input'

  debug "Fussy.file(\"#{input}\")"
  mimetype = mime.lookup input
  #debug "MIME type: #{mimetype}"

  switch mimetype

    when 'text/csv'
      lazy = Lazy
        .readFile(input)
        #.async()
        .lines()
      Fussy.lazy lazy

    when 'application/zip'

      #
      lazySequence = new StreamedSequence(undefined)

      fs
        .createReadStream(input, { autoClose: yes })
        .pipe(unzip.Parse())
        .on 'entry', (entry) ->
          if entry.type is 'Directory'
            debug "ignoring directory"
            entry.autodrain()
            return

          type = mime.lookup entry.path
          switch type
            when 'text/csv'
              debug "found a csv file in the archive, reading: #{entry.path} (size: #{entry.size})"
              if lazySequence.stream?
                debug "error, lazy sequence already initialized"
                entry.autodrain()
                return
              else
                debug "initializing lazy sequence"
                lazySequence.stream = entry
            else
              debug "found some \"#{type}\" in the archive, ignoring: #{entry.path}"
              entry.autodrain()

      lazySequence

    else
      throw """ unsupported file type "#{type}" """

Fussy.http = (url) ->
  if !input? or input is ''
    throw new Error 'Empty or null input'
  Fussy.lazy(Lazy.makeHttpRequest(url).lines())

# guess the kind of stream
Fussy.open = (url) ->
  unless isString input
    return Fussy.lazy(Lazy(input))

  {protocol, path} = Url.parse url

  switch protocol

    when 'http:','http+csv:','http+json', 'https:','https+csv:','https+json'
      debug "http: making an http request"
      Fussy.http url

    when 'file:','file+csv:','file+json:','file+txt:'
      debug "file: reading a file stream from url's path"
      Fussy.file path

    else #when undefined
      debug "default: reading a file stream from normal path"
      Fussy.file url

    #else
    #  debug "default: reading a text file already loaded a string"
    #  Fussy.lazy(Lazy(url).lines())
