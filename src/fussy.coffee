# standard node library
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

debugEnabled = no
debug = (x) ->
  return unless debugEnabled
  console.log x
detach = (f) -> setTimeout f, 0

class Query
  constructor: (db, q) ->
    @_error = undefined
    @_mode = 'all'

    if q.select?

      if utils.isString q.select
        tmp = {}
        tmp[q.select] = []
        q.select = tmp

      else if utils.isArray q.select
        tmp = {}
        for select in q.select
          tmp[select] = []
        q.select = tmp

      # else we assume this is a correctly formatted object

    unless utils.isArray q.where
      q.where = [ q.where ]

    @_db = db
    @_query = q

  debug: (enabled) ->
    return debugEnabled unless enabled?
    debug "Query".yellow + "::debug(value) " + " // setting debug to ".grey + "#{pretty enabled}"
    debugEnabled = enabled
    @

  _reduceFn: (reduction, features) ->
    debug "Query".green + "::reduceFn(reduction, features)" +" // deep comparison".grey
    unless features?
      debug "Query".green + "::reduceFn: end condition"
      return reduction

    query = reduction.query
    #debug "reduction: " + pretty reduction
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
      unless key of reduction.types
        reduction.types[key] = type

      # TODO put the 4 following lines before the "continue unless"
      # if you want to catch all results
      unless key of reduction.result
        reduction.result[key] = {}

      unless value of reduction.result[key]
        reduction.result[key][value] = 0


      #debug "match for #{key}: #{query.select[key]}"

      match = no
      if query.select?
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
      else
        match = yes

      if match
        reduction.result[key][value] += weight

    debug "Query".green + "::_reduceFn: reducing"
    #debug pretty reduction
    return reduction

  _sortFn: (input, cb) ->
    debug "Query".green + "::_sortFn(input, cb?)"+" // sort options by probability".grey
    output = input.sort (a,b) -> b[2] - a[2]
    if cb?
      cb output
      return undefined
    else
      return output

  _toBestFn: (args) ->
    debug "Query".green + "::_toBestFn(args)"
    {result, types} = args

    output = {}
    for key, options of result
      isNumerical = types[key] is 'Number'

      if utils.isNumerical

        sum = 0
        for option, weight of options
          sum += weight

        output[key] = 0
        for option, weight of options
          option = (Number) option
          output[key] += option * (weight / sum)

      else
        output[key] = []
        for option, weight of options
          if types[key] is 'Boolean'
            option = (Boolean) option
          output[key].push [option, weight]
        output[key].sort (a,b) -> b[1] - a[1]
        best = output[key][0] # get the best
        output[key] = best[0] # get the value

    if cb?
      cb output
      return undefined
    else
      return output


  # convert a key:{ opt_a:3, opt_b: 4}
  _toAllFn: (args, cb) ->

    debug "Query".green + "::_toAllFn(args, cb?)"+"  // cast output map to typed array"

    __toAllFn = (args) ->
      debug "Query".green + "::_toAllFn:__toAllFn(#{pretty args})"
      res = {}
      for key, options of args.result
        res[key] = if args.types[key] is 'Number'
            debug "Query".green + "::_toAllFn:__toAllFn: Number -> #{key}"
            for option, weight of options
              [key, (Number) option, weight]
          else if args.types[key] is 'Boolean'
            debug "Query".green + "::_toAllFn:__toAllFn: Boolean -> #{key}"
            for option, weight of options
              [key, (Boolean) option, weight]
          else
            debug "Query".green + "::_toAllFn:__toAllFn: String -> #{key}"
            for option, weight of options
              [key, option, weight]
    if cb?
      result = __toAllFn args
      cb result
      return undefined
    else
      result = __toAllFn args
      return result


  all: (cb) ->
    debug "Query".green + "::all(cb?)"
    @_mode = 'all'
    if cb? then @_async(cb) else @_sync()

  best: (cb) ->
    debug "Query".green + "::mix(cb?)"
    @_mode = 'best'
    if cb? then @_async(cb) else @_sync()

  replace: (cb) ->
    debug "Query".green + "::replace(cb?)"
    @_mode = 'replace'
    if cb? then @_async(cb) else @_sync()


  # toArray = get sync
  _sync: ->
    debug "Query".green + "::_sync()"

    ctx =
      reduction:
        query: @_query
        result: {}
        types: {}

    debug "Query".green + "::_sync: @_db.eachFeatureSync:"
    @_db.eachFeaturesSync (features, isLastItem) =>
      debug "Query".green + "::_sync: @_db.eachFeatureSync(#{pretty features}, #{pretty isLastItem})"
      ctx.reduction = @_reduceFn ctx.reduction, features

    results = switch @_mode
      when 'all'
        debug "Query".green + "::_sync: all: @_toAllFn(#{pretty ctx.reduction})"
        results = @_toAllFn ctx.reduction
        @_sortFn results

      when 'best'
        debug "Query".green + "::_sync: best: @_toBestFn(#{pretty ctx.reduction})"
        @_toBestFn ctx.reduction

      when 'replace'
        debug "Query".green + "::_sync: fix: @_toBestFn(#{pretty ctx.reduction})"
        result = @_toBestFn ctx.reduction

        obj = ctx.reduction.query.replace
        for k,v of result
          if !obj[k]?
            obj[k] = v
        obj


    debug "Query".green + "::_sync: return #{pretty results}"
    results

  onError: (cb) ->
    debug "Query".green + "::onError(cb)"
    @_onError = cb

  # onComplete = get async
  _async: (cb) ->

    debug "Query".green + "::_async(cb)"

    ctx =
      reduction:
        query: @_query
        result: {}
        types: {}

    debug "Query".green + "::_async: @_db.eachFeatureAsync:"
    @_db.eachFeaturesAsync (features, isLastItem) =>
      debug "Query".green + "::_async: @_db.eachFeatureAsync(#{pretty features}, #{pretty isLastItem})"

      debug "Query".green + "::_async: @_reduceFn(ctx.reduction, features)"
      ctx.reduction = @_reduceFn ctx.reduction, features
      return unless isLastItem
      debug "Query".green + "::_async: isLastItem == true"

      results = switch @_mode
        when 'all'
          # sync
          debug "Query".green + "::_async: all: @_toAllFn(ctx.reduction, cb)"
          @_toAllFn ctx.reduction, (results) =>

            # sync too
            debug "Query".green + "::_async: all: @_sortFn(results, cb)"
            @_sortFn results, (results) =>

              debug "Query".green + "::_async: all: cb(results)"
              cb results

        when 'best'
          debug "Query".green + "::_async: best: @_toBestFn(#{pretty ctx.reduction})"
          @_toBestFn ctx.reduction, (best) =>

            debug "Query".green + "::_async: best: cb(results)"
            cb results

        when 'fix'
          debug "Query".green + "::_async: fix: @_toBestFn(#{pretty ctx.reduction})"
          @_toBestFn ctx.reduction, (best) =>
            obj = ctx.reduction.query.replace
            for k,v of result
              if !obj[k]?
                obj[k] = v
            obj
            cb obj

    return undefined

class File
  constructor: (@_fussy, @_url) ->

    parsed = Url.parse @_url

    @_path = parsed.path

    if !parsed.protocol?
      @_path = @_url


  # actually, even if we are synchronous, we could do something smarter
  # using the low level file read (ie. only load the file chunk by chunk,
  # synchronously)
  eachSync: (cb) ->
    debug "File".blue + "::eachSync(cb)"
    fs = require 'fs'
    str = fs.readFileSync @_path, 'utf-8'
    lines = str.split('\n')
    i = 0
    for line in lines
      cb line, no
      i += 1
    cb undefined, yes


  eachAsync: (cb) ->
    debug "File".blue + "::eachAsync(cb)"
    fs = require 'fs'
    readline = require 'readline'
    stream = require 'stream'

    instream = fs.createReadStream @_path
    outstream = new stream
    rl = readline.createInterface instream, outstream

    i = 0
    rl.on 'line', (line) ->
      cb line, no
      i += 1

    rl.on 'close', ->
      cb undefined, yes

    return undefined

class Mongo

  constructor: (@_fussy, @_url) ->

    parsed = Url.parse @_url

    @_host = parsed.hostname ? '127.0.0.1'
    @_port = (Number) (parsed.port ? '27017')

    path   = parsed.path ? '/fussy/fussy'
    @_database   = path[0]
    @_collection = path[1]

    @_batchSize = 1024

  # iterate synchronously over a mongo collection
  eachSync: (cb) ->
    debug 'Mongo::eachSync'

    limit = @_fussy.limit()
    skip = @_fussy.skip()

    Server = require('mongo-sync').Server

    db = new Server @_host

    debug "Mongo".blue + "::eachSync: gettin cursor on database and collection"
    cursor = db
      .db(@_database)
      .getCollection(@_collection)
      .find()

    if skip?
      debug "Mongo".blue + "::eachSync: skipping #{skip} results of collection"
      cursor = cursor.skip skip

    if limit?
      debug "Mongo".blue + "::eachSync: limiting #{limit} results of collection"
      cursor = cursor.limit limit

    results = cursor.toArray()

    i = 0
    size = results.length
    for item in results
      cb item, no
    cb undefined, yes
    db.close()
    return undefined

  # iterate asynchronously over a mongo collection
  eachAsync: (cb) ->
    debug "Mongo".blue + "::eachAsync(cb)"

    MongoClient = require('mongodb').MongoClient
    collection = @_collection
    limit = @_fussy.limit()
    skip = @_fussy.skip()
    delay = 0 # async delay

    debug "Mongo".blue + "::eachAsync: connecting to mongo (#{@_host}:#{@_port})"
    MongoClient.connect "mongodb://#{@_host}:#{@_port}/#{_database}", (err, db) ->
      throw err if err

      debug "Mongo".blue + "::eachAsync: gettin cursor on database and collection"
      cursor = db
        .collection(collection)
        .find()

      if skip?
        debug "Mongo".blue + "::eachSync: skipping #{skip} results of collection"
        cursor = cursor.skip skip

      if limit?
        debug "Mongo".blue + "::eachSync: limiting #{limit} results of collection"
        cursor = cursor.limit limit

      cursor = cursor
        .batchSize(@_batchSize)

      # this function is closure-safe (we could put it outside in a library)
      _readCursor = (cursor, i, delay, db, next) ->
        cursor.nextObject (err, item) ->
          debug "Mongo".blue + "::eachAsync:_readCursor: cursor.nextObject(function(err, item){})"
          throw err if err
          if item
            debug "                          - returned an item"
            cb item, yes
            fn = -> next(cursor, i+1, delay)
            setTimeout fn, delay
          else
            debug "                          - returned nothing: end reached"
            cb undefined, yes
            db.close()

      debug "Mongo".blue + "::eachAsync: calling _readCursor(cursor, 0, delay, db, next)"
      _readCursor(cursor, 0, delay, db, _readCursor)
    return undefined

class Fussy

  constructor: (input) ->

    @_skip = undefined # 0
    @_limit = undefined # Infinity

    parsed = Url.parse input

    switch parsed.protocol
      when 'rest:','http:','http+rest:','http+json', 'https:','https+rest:','https+json'
        debug "Fussy".yellow + "::constructor: protocol is http rest"
        throw "http rest protocol is not supported yet"

      when 'file:','file+csv:','file+json:','file+txt:'
        debug "Fussy".yellow + "::constructor: protocol is file"
        @_engine = new File @, input

      when 'mongo:', 'mongodb:'
        debug "Fussy".yellow + "::constructor: protocol is MongoDB"
        @_engine = new Mongo @, input

      else #when undefined
        debug "Fussy".yellow + "::constructor: protocol is default (file)"
        @_engine = new File @, input

  _parse: (input) ->

    #debug "Fussy".yellow + "::_parse(input) " +"  // convert raw chunk into full featured object".grey
    #debug input
    output = undefined
    #debug "map: extracting features from "+JSON.stringify input

    # do we have a schema defined?
    if @_schema?
      debug "Fussy".yellow + "::_parse: using schema"
      if utils.isString input
        #debug "Fussy".yellow + "::_parse: trying to parse csv line using schema"
        #debug "Fussy".yellow + "::_parse: line: "+input
        try
          output = utils.parse @_schema, input
        catch exc
          #debug exc
          debug "Fussy".yellow + "::_parse: couldn't parse input, trying to parse json from string"
          try
            output = JSON.parse input
          catch exc
            #debug exc
            debug "Fussy".yellow + "::_parse: couldn't parse json input. I could use the object as is, but since you defined a schema I prefer to skip it"
            output = undefined
      else
        output = input

    else if utils.isString input
      debug "Fussy".yellow + "::_parse: no schema, trying to parse json from string"
      output = JSON.parse input
    else
      debug "Fussy".yellow + "::_parse: no schema, using js object as-is"
      output = input
    debug "Fussy".yellow + "::_parse: #{pretty input} =====> #{pretty output}"
    #debug "extracting output"
    output

  _extract: (event, facts=[], prefix="") ->
    debug "Fussy".yellow + "::_extract(event)"
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
    throw "cannot set an undefined schema" if !schema?
    @_schema = utils.loadSchema schema
    @

  limit: (limit) ->
    return @_limit unless limit?
    throw "limit must be >= 0" if limit < 0
    debug "Fussy".yellow + "::limit(value) " + " // setting limit to ".grey + "#{pretty limit}"
    @_limit = limit
    @

  skip: (skip) ->
    return @_skip unless skip?
    throw "skip must be >= 0" if skip < 0
    debug "Fussy".yellow + "::skip(value) " + " // setting skip to ".grey + "#{pretty skip}"
    @_skip = skip
    @

  debug: (enabled) ->
    return debugEnabled unless enabled?
    debug "Fussy".yellow + "::debug(value) " + " // setting debug to ".grey + "#{pretty enabled}"
    debugEnabled = enabled
    @

  ###
  Call a function on each item, synchronously
  (the function will only returns once all items have been read)
  This functions skips invalid items
  ###
  eachFeaturesSync: (cb) ->
    debug "Fussy".yellow + "::eachFeaturesSync(cb)"
    @_engine.eachSync (item, eof) =>
      debug "Fussy".green + "::eachFeaturesSync: @_engine.eachSync (item=#{pretty item}, eof=#{pretty eof})"

      # if end reached, return immediately
      if eof
        cb undefined, eof
        return

      extracted = @_parse item
      return unless extracted
      features = @_extract extracted
      return unless features
      cb features, eof

  ###
  Call a function on each item, asynchronously
  ###
  eachFeaturesAsync: (cb) => detach =>
    debug "Fussy".yellow + "::eachFeaturesAsync(cb)"
    @_engine.eachAsync (item, eof) =>
      debug "Fussy".green + "::eachFeaturesAsync: @_engine.eachAsync (item=#{pretty item}, eof=#{pretty eof})"


      # if end reached, return immediately
      if eof
        cb undefined, eof
        return

      extracted = @_parse item
      return unless extracted
      features = @_extract extracted
      return unless features
      cb features, eof

  onComplete: (onCompleteCb) ->
    debug "Fussy".yellow + "::_onCompleteCb = onCompleteCb"
    @_onCompleteCb = onCompleteCb
    @

  query: (query) ->
    new Query @, query

  ###
  Repair an object in-place
  Only fields that are undefined will be filled, others will be left untouched
  ###
  repair: (obj, cb) ->

    query = new Query @,
      replace: obj
      select: Object.keys(obj)
      where: do ->
        newObj = {}
        for key in Object.keys(obj)
          if obj[key]?
            newObj[key] = obj[key]
        newObj

    query.replace cb


  solve: (obj, cb) ->

    query = new Query @,
      select: Object.keys(obj)
      where: do ->
        newObj = {}
        for key in Object.keys(obj)
          if obj[key]?
            newObj[key] = obj[key]
        newObj

    query.best()

module.exports =

  debug: (enabled) ->
    debugEnabled = enabled
    @

  pretty: utils.pretty
  pperf: utils.pperf
  pstats: utils.pstats

  input: (input) ->
    new Fussy input
