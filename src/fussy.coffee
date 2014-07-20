"use strict"

# standard node library
Url    = require 'url'


# third party modules
colors    = require 'colors'
csvString = require 'csv-string' # csv row parser

# our modules
utils   = require './utils'

# protocols
List    = require './protocols/list'  # arrays
File    = require './protocols/file'  # single csv file
Glob    = require './protocols/glob'  # multiple json files
Http    = require './protocols/http'  # remove csv files
Mongo   = require './protocols/mongo' # mongodb collections

Query  = require './query'

pretty = utils.pretty


class Fussy

  constructor: (input, @_debugEnabled) ->


    @_skip = undefined # 0
    @_limit = undefined # Infinity

    @_firstLine = yes
    @_custom_schema = no

    if utils.isArray input
      @_engine = new List @, input

    else if utils.isString input

      parsed = Url.parse input

      switch parsed.protocol
        when 'rest:','http:','http+rest:','http+json', 'https:','https+rest:','https+json'
          @_debug "constructor: protocol is http rest"
          @_engine new Http @, input

        when 'file:','file+csv:','file+json:','file+txt:'
          @_debug "constructor: protocol is file"
          if parsed.path[-1..] is '/' or parsed.path.match /\*/
            @_engine = new Glob @, input
          else
            @_engine = new File @, input


        when 'mongo:', 'mongodb:'
          @_debug "constructor: protocol is MongoDB"
          @_engine = new Mongo @, input

        else #when undefined
          @_debug "constructor: protocol is default (file)"
          if parsed.path[-1..] is '/' or parsed.path.match /\*/
            @_engine = new Glob @, input
          else
            @_engine = new File @, input

    else
      throw "unsupported input type"


  debug: (enabled) ->
    @_debugEnabled = enabled
    @

  _debug: (x) ->
    return unless @_debugEnabled
    console.log "Fussy".yellow  + "::".grey + x

  ###

  ###
  _parse: (input) ->

    # fear not, nor be ye dismayed at the sight of the decision tree

    #@_debug "_parse(input) " +"  // convert raw chunk into full featured object".grey

    output = undefined

    # do we have a schema defined?
    if @_schema?
      @_debug "_parse: using schema"
      if utils.isString input
        #@_debug "_parse: trying to parse csv line using schema"
        #@_debug "_parse: line: "+input
        if @_custom_schema
          @_debug "_parse: this is a custom schema, we need to update it"
          try
            tmp = csvString.parse(input)[0]
            i = 0
            for item in tmp
              value = (Number) item
              @_debug "_parse: #{value} = (Number) #{item}"
              if value? and !isNaN(value) and isFinite(value)
                @_schema[i][1] = 'Number'
              i += 1
            @_debug "_parse: updated schema: #{pretty @_schema}"
          catch exc
            @_debug "_parse: schema update failed: #{exc}"

        try
          output = utils.parse @_schema, input
        catch exc
          #@_debug exc
          @_debug "_parse: couldn't parse input, trying to parse json from string"
          try
            output = JSON.parse input
          catch exc
            #@_debug exc
            @_debug "_parse: couldn't parse json input. I could use the object as is, but since you defined a schema I prefer to skip it"
            output = undefined
      else
        @_debug "_parse: object is not a string, so we won't parse it"
        output = input

    else if utils.isString input
      @_debug "_parse: no schema, trying to parse json from string"
      try
        output = JSON.parse input
      catch exc
        @_debug exc
        @_debug "_parse: uh-oh, not a JSON. Trying CSV.."
        try
          tmp = csvString.parse(input)[0]
          output = {}

          if !@_schema?

            @_debug "_parse: no schema! trying to detect if the row is a header.."

            @_custom_schema = yes

            @_schema = for item in tmp
              [item, 'String']

            inputIsProbablyHeader = do ->
              for item in tmp
                value = (Number) item
                if value? and !isNaN(value) and isFinite(value)
                  @_debug "_parse: definitely not a header"
                  return no
              @_debug "_parse: maybe a header?"
              return yes

            if inputIsProbablyHeader
              @_debug "_parse: input looks like a header, writing schema and skipping"
            else
              @_debug "_parse: not a header, so creating dummy schema and re-parsing input"
              return @_parse input

        catch exc2
          @_debug exc2
          @_debug "_parse: document is not a JSON object and not a CSV array: skipping it".yellow

    else
      @_debug "_parse: object is not a string, so we won't parse it"
      output = input
    @_debug "_parse: #{pretty input} =====> #{pretty output}"
    #@_debug "extracting output"
    output

  _extract: (event, facts=[], prefix="") ->
    @_debug "_extract(event)"
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


    for key, value of event

      key = prefix + key
      #console.log "key: #{key}"

      # TODO we should use in priority the schema for this, then only detect type
      # as a fallback

      if utils.isString value
        @_debug "_extract: String"
        if value isnt ""
          facts.push ['String', key, value]

      else if utils.isArray value
        @_debug "_extract: Array"
        facts.push ['Array', key, value]

      else if utils.isNumber value
        @_debug "_extract: Number"
        facts.push ['Number', key, value]

      else if utils.isBoolean value
        @_debug "_extract: Boolean"
        facts.push ['Boolean', key, value]

      else
        #console.log "recursive"
        @_extract value, facts, key + "." # recursively flatten nested features


    #console.log "facts: " + JSON.stringify facts
    facts

  schema: (schema) ->
    throw "cannot set an undefined schema" if !schema?
    @_schema = utils.loadSchema schema
    @

  limit: (limit) ->
    return @_limit unless limit?
    throw "limit must be >= 0" if limit < 0
    @_debug "limit(value) " + " // setting limit to ".grey + "#{pretty limit}"
    @_limit = limit
    @

  skip: (skip) ->
    return @_skip unless skip?
    throw "skip must be >= 0" if skip < 0
    @_debug "skip(value) " + " // setting skip to ".grey + "#{pretty skip}"
    @_skip = skip
    @


  ###
  Call a function on each item, synchronously
  (the function will only returns once all items have been read)
  This functions skips invalid items
  ###
  eachFeaturesSync: (cb) ->
    @_debug "eachFeaturesSync(cb)"
    @_engine.eachSync (item, eof) =>
      @_debug "eachFeaturesSync: @_engine.eachSync (item=#{pretty item}, eof=#{pretty eof})"

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
  eachFeaturesAsync: (cb) =>
    @_debug "eachFeaturesAsync(cb)"
    @_engine.eachAsync (item, eof) =>
      @_debug "eachFeaturesAsync: @_engine.eachAsync (item=#{pretty item}, eof=#{pretty eof})"


      # if end reached, return immediately
      if eof
        cb undefined, eof
        return

      extracted = @_parse item
      return unless extracted
      features = @_extract extracted
      return unless features
      cb features, eof
    return

  onComplete: (onCompleteCb) ->
    @_debug "_onCompleteCb:(onCompleteCb)"
    @_onCompleteCb = onCompleteCb
    @

  query: (query) ->
    unless query?
      throw "Error: Fussy.query cannot be called without parameters".red
    new Query @, query

  ###
  Repair an object in-place
  Only fields that are undefined will be filled, others will be left untouched
  ###
  repair: (obj, cb) ->
    unless obj?
      throw "Error: Fussy.repair cannot be called without parameters".red
    #if utils.isArray(obj) and obj.length > 0

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

  ###
  Return the solution to an uncomplete json object
  ###
  solve: (obj, cb) ->
    unless obj?
      throw "Error: Fussy.solve cannot be called without parameters".red

    @_debug "solve(obj, cb)"
    query = new Query @,
      select: Object.keys(obj)
      where: do ->
        newObj = {}
        for key in Object.keys(obj)
          if obj[key]?
            newObj[key] = obj[key]
        newObj

    query.best cb

  ###
  Return a new json object with random attribute value, depending on the
  probability of each
  there is an optional argument, 'n', to specify the number of desired instances
  ###
  pick: (obj, n, cb) ->

    @_debug "pick(obj, n, cb)"
    n = if utils.isNumber(n) then n else 1
    cb = if utils.isFunction(n) then n else cb

    obj ?= {}

    query = new Query @,
      select: Object.keys(obj)
      where: do ->
        newObj = {}
        for key in Object.keys(obj)
          if obj[key]?
            newObj[key] = obj[key]
        newObj

    query.pick n, cb

  ###
  generate() generates a generator function
  ###
  generate: (obj, cb) ->
    @_debug "generate(obj, cb)"
    obj ?= {}

    query = new Query @,
      select: Object.keys(obj)
      where: do ->
        newObj = {}
        for key in Object.keys(obj)
          if obj[key]?
            newObj[key] = obj[key]
        newObj

    query.generate cb

  ###
  test some data (this is a WIP, to replace the bench object)
  ###
  test: (input, cb) ->
    testDataset = module.exports.input input

    if cb?
      @_debug "test: async"
      @eachFeaturesAsync (item, eof) =>
        0
    else
      @_debug "test: sync"
      @eachFeaturesSync (item, eof) =>
        0

module.exports = (input) ->
  new Fussy input, module.exports._debugEnabled

module.exports.debug = (enabled) ->
  module.exports._debugEnabled = enabled
  module.exports

module.exports.pretty = utils.pretty
module.exports.pperf = utils.pperf
module.exports.pstats = utils.pstats
