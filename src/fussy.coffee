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
debug = (x) -> console.log x


class Query
  constructor: (db, q) ->
    @_error = undefined

    if q.select?

      if utils.isString @qlect
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


  _reduceFn: (reduction, features) ->
    debug "Query::reduceFn(reduction, features)" +" // deep comparison".grey
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
        reduction.result[key][value] += weight

    debug "generated reduction result"
    #debug pretty reduction
    reduction

  _sortFn: (input, cb) ->
    debug "Query::_sortFn(input, cb?)"+" // sort options by probability".grey
    output = input.sort (a,b) -> b[2] - a[2]
    if cb?
      cb output
      return undefined
    else
      return output

  # convert a key:{ opt_a:3, opt_b: 4}
  _castFn: (args, cb) ->

    debug "Query::_castFn(args, cb?)"+"  // cast output map to typed array"

    __castFn = (args) ->
      debug "Query::_castFn:__castFn(args)"
      [key, options] = args.result
      if args.types[key] is 'Number'
        for option, weight of options
          [key, (Number) option, weight]
      else if args.types[key] is 'Boolean'
        for option, weight of options
          [key, (Boolean) option, weight]
      else
        for option, weight of options
          [key, option, weight]
    if cb?
      cb __castFn args
      return undefined
    else
      return __castFn args

  get: (cb) ->
    debug "Query::get(cb?)"
    if cb? then @onComplete(cb) else @toArray()

  # toArray = get sync
  toArray: ->
    debug "Query::toArray()"

    ctx =
      reduction:
        result: {}
        types: {}

    debug "Query::toArray: @_db.eachFeatureSync:"
    @_db.eachFeaturesSync (features, index, isLastItem) =>
      debug "Query::toArray: @_db.eachFeatureSync(#{prerry features},#{pretty index},#{pretty isLastItem})"
      ctx.reduction = @_reduceFn ctx.reduction, features

    debug "Query::toArray: @_castFn(sorted)"
    casted = @_castFn ctx.reduction

    debug "Query::toArray: @_sortFn(casted)"
    sorted = @_sortFn casted

    debug "Query::toArray: return"
    sorted

  onError: (cb) ->
    debug "Query::onError(cb)"
    @_onError = cb

  # onComplete = get async
  onComplete: (cb) ->

    debug "Query::onComplete(cb)"

    ctx =
      reduction:
        result: {}
        types: {}

    debug "Query::onComplete: @_db.eachFeatureAsync:"
    @_db.eachFeaturesAsync (features, index, isLastItem) =>
      debug "Query::onComplete:   @_db.eachFeatureAsync(#{pretty features},#{pretty index},#{pretty isLastItem})"

      debug "Query::onComplete:     @_reduceFn(ctx.reduction, features)"
      ctx.reduction = @_reduceFn ctx.reduction, features
      return unless isLastItem
      debug "Query::onComplete:     isLastItem == true"
      # sync
      debug "Query::onComplete:   @_castFn(ctx.reduction, cb)"
      @_castFn ctx.reduction, (casted) ->

        # sync too
        debug "Query::onComplete:   @_sortFn(casted, cb)"
        @_sortFn casted, (sorted) ->

          debug "Query::onComplete: cb(sorted)"
          cb sorted

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
    debug "File::eachSync(cb)"
    fs = require 'fs'
    str = fs.readFileSync @_path, 'utf-8'
    lines = str.split('\n')
    i = 0
    for line in lines
      cb line, i, no
      i += 1
    cb undefined, i, yes


  eachAsync: (cb) ->
    debug "File::eachAsync(cb)"
    fs = require 'fs'
    readline = require 'readline'
    stream = require 'stream'

    instream = fs.createReadStream @_path
    outstream = new stream
    rl = readline.createInterface instream, outstream

    i = 0
    rl.on 'line', (line) ->
      cb line, i, no
      i += 1

    rl.on 'close', ->
      cb undefined, i, yes

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

    debug "Mongo::eachSync: gettin cursor on database and collection"
    cursor = db
      .db(@_database)
      .getCollection(@_collection)
      .find()

    if skip?
      debug "Mongo::eachSync: skipping #{skip} results of collection"
      cursor = cursor.skip skip

    if limit?
      debug "Mongo::eachSync: limiting #{limit} results of collection"
      cursor = cursor.limit limit

    results = cursor.toArray()

    i = 0
    size = results.length
    for item in results
      cb item, i, no
    cb undefined, size, yes
    db.close()
    return undefined

  # iterate asynchronously over a mongo collection
  eachAsync: (cb) ->
    debug "Mongo::eachAsync(cb)"

    MongoClient = require('mongodb').MongoClient
    collection = @_collection
    limit = @_fussy.limit()
    skip = @_fussy.skip()
    delay = 0 # async delay

    debug "Mongo::eachAsync: connecting to mongo (#{@_host}:#{@_port})"
    MongoClient.connect "mongodb://#{@_host}:#{@_port}/#{_database}", (err, db) ->
      throw err if err

      debug "Mongo::eachAsync: gettin cursor on database and collection"
      cursor = db
        .collection(collection)
        .find()

      if skip?
        debug "Mongo::eachSync: skipping #{skip} results of collection"
        cursor = cursor.skip skip

      if limit?
        debug "Mongo::eachSync: limiting #{limit} results of collection"
        cursor = cursor.limit limit

      cursor = cursor
        .batchSize(@_batchSize)

      # this function is closure-safe (we could put it outside in a library)
      _readCursor = (cursor, i, delay, db, next) ->
        cursor.nextObject (err, item) ->
          debug "Mongo::eachAsync:_readCursor: cursor.nextObject(function(err, item){})"
          throw err if err
          if item
            debug "                          - returned an item"
            cb item, i, yes
            fn = -> next(cursor, i+1, delay)
            setTimeout fn, delay
          else
            debug "                          - returned nothing: end reached"
            cb undefined, i, yes
            db.close()

      debug "Mongo::eachAsync: calling _readCursor(cursor, 0, delay, db, next)"
      _readCursor(cursor, 0, delay, db, _readCursor)
    return undefined


class Database

  constructor: (input) ->

    @_skip = undefined # 0
    @_limit = undefined # Infinity

    parsed = Url.parse input

    switch parsed.protocol
      when 'rest:','http:','http+rest:','http+json', 'https:','https+rest:','https+json'
        debug "Database::constructor: protocol is http rest"
        throw "http rest protocol is not supported yet"

      when 'file:','file+csv:','file+json:','file+txt:'
        debug "Database::constructor: protocol is file"
        @_engine = new File @, input

      when 'mongo:', 'mongodb:'
        debug "Database::constructor: protocol is MongoDB"
        @_engine = new Mongo @, input

      else #when undefined
        debug "Database::constructor: protocol is default (file)"
        @_engine = new File @, input

  _parse: (input) ->

    debug "Database::_parse(input) " +"  // convert raw chunk into full featured object".grey
    #debug input
    output = undefined
    #debug "map: extracting features from "+JSON.stringify input

    # do we have a schema defined?
    if @_schema?
      if utils.isString input
        debug "trying to parse csv line using schema"
        debug "line: "+input
        try
          output = utils.parse @_schema, input
        catch exc
          #debug exc
          debug "Database::_parse: couldn't parse input, trying to parse json from string"
          try
            output = JSON.parse input
          catch exc
            #debug exc
            debug "Database::_parse: couldn't parse json input. I could use the object as is, but since you defined a schema I prefer to skip it"
            output = undefined
      else
        output = input

    else if utils.isString input
      debug "Database::_parse: no schema, trying to parse json from string"
      output = JSON.parse input
    else
      debug "Database::_parse: no schema, using js object as-is"
      output = input
    debug "Database::_parse: #{pretty input} =====> #{pretty output}"
    #debug "extracting output"
    output

  _extract: (event, facts=[], prefix="") ->
    debug "Database::_extract(event)"
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
    @_schema = schema
    @

  limit: (limit) ->
    return @_limit unless limit?
    throw "limit must be >= 0" if limit < 0
    debug "Database::limit(value) " + " // setting limit to ".grey + "#{pretty limit}"
    @_limit = limit
    @

  skip: (skip) ->
    return @_skip unless skip?
    throw "skip must be >= 0" if skip < 0
    debug "Database::skip(value) " + " // setting skip to ".grey + "#{pretty skip}"
    @_skip = skip
    @

  eachFeaturesSync: (cb) ->
    debug "Database::eachFeaturesSync(cb)"
    @_engine.eachSync (item, index, eof) =>
      features = @_extract @_parse item
      cb features, index, eof

  eachFeaturesAsync: (cb) ->
    debug "Database::eachFeaturesAsync(cb)"
    @_engine.eachAsync (item, index, eof) =>
      features = @_extract @_parse item
      cb features, index, eof

  onComplete: (onCompleteCb) ->
    debug "Database::_onCompleteCb = onCompleteCb"
    @_onCompleteCb = onCompleteCb
    @

  query: (query) ->
    new Query @, query


module.exports =

  pretty: utils.pretty
  pperf: utils.pperf
  pstats: utils.pstats

  database: (input) ->
    new Database input
