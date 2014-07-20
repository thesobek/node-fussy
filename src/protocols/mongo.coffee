"use strict"

# standard node library
util   = require 'util'
Url    = require 'url'

# third party modules
mime      = require 'mime'
colors    = require 'colors'
csvString = require 'csv-string' # csv row parser

# our modules
utils   = require '../utils'

pretty = utils.pretty

###
for repair() and batch processing, we might want to use this:
https://www.npmjs.org/package/mongo-writable-stream
###
class Mongo

  constructor: (@_fussy, @_url) ->

    parsed = Url.parse @_url

    @_host = parsed.hostname ? '127.0.0.1'
    @_port = (Number) (parsed.port ? '27017')

    path   = (parsed.path ? '/fussy/fussy').split '/'

    @_database   = path[1]
    @_collection = path[2]

    @_batchSize = 1024

  debug: (enabled) ->
    @_debugEnabled = enabled
    @

  _debug: (x) ->
    # use master debug setting, unless we overloaded it for our protocol
    return unless (if @_debugEnabled? then @_debugEnabled else @_fussy._debugEnabled)
    console.log "Mongo".blue + "::".grey + x

  # iterate synchronously over a mongo collection
  eachSync: (cb) ->
    @_debug 'eachSync'

    throw "eachSync not supported for Mongo protocol"

    limit = @_fussy.limit()
    skip = @_fussy.skip()

    Server = require('mongo-sync').Server

    db = new Server @_host

    @_debug "eachSync: gettin cursor on database and collection"
    cursor = db
      .db(@_database)
      .getCollection(@_collection)
      .find()

    if skip?
      @_debug "eachSync: skipping #{skip} results of collection"
      cursor = cursor.skip skip

    if limit?
      @_debug "eachSync: limiting #{limit} results of collection"
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
    @_debug "eachAsync:"

    MongoClient = require('mongodb').MongoClient
    collection = @_collection
    limit = @_fussy.limit()
    skip = @_fussy.skip()
    delay = 0 # async delay

    @_debug "eachAsync: connecting to mongo (#{@_host}:#{@_port})/#{pretty @_database}"
    opts =
      db: native_parser: yes

    MongoClient.connect "mongodb://#{@_host}:#{@_port}/#{@_database}", opts, (err, db) =>
      @_debug "err: #{pretty err}"
      throw err if err

      @_debug "eachAsync: gettin cursor on database and collection"
      cursor = db
        .collection(collection)
        .find()

      if skip?
        @_debug "eachAsync: skipping #{skip} results of collection"
        cursor = cursor.skip skip

      if limit?
        @_debug "eachAsync: limiting #{limit} results of collection"
        cursor = cursor.limit limit

      cursor = cursor
        .batchSize(@_batchSize)

      #cursor.each (err, doc) =>
      #  @_debug "cursor.each(#{pretty err}, #{pretty doc})"
      #
      #return

      # this function is closure-safe (we could put it outside in a library)
      _readCursor = (i) =>
        cursor.nextObject (err, item) =>
          @_debug "eachAsync._readCursor: cursor.nextObject (#{err}, #{pretty item})"
          throw err if err
          if item
            @_debug "                          - returned an item"
            cb item, no
            fn = -> _readCursor i+1
            setTimeout fn, delay
          else
            @_debug "                          - returned nothing: end reached"
            cb undefined, yes
            db.close()

      @_debug "eachAsync: _readCursor(cursor, 0, delay, db, next)"
      _readCursor 0
    return undefined

module.exports = Mongo
