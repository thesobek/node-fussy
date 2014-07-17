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

class Mongo

  constructor: (@_fussy, @_url) ->

    parsed = Url.parse @_url

    @_host = parsed.hostname ? '127.0.0.1'
    @_port = (Number) (parsed.port ? '27017')

    path   = parsed.path ? '/fussy/fussy'
    @_database   = path[0]
    @_collection = path[1]

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
    @_debug 'Mongo::eachSync'

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
    @_debug "eachAsync(cb)"

    MongoClient = require('mongodb').MongoClient
    collection = @_collection
    limit = @_fussy.limit()
    skip = @_fussy.skip()
    delay = 0 # async delay

    @_debug "eachAsync: connecting to mongo (#{@_host}:#{@_port})"
    MongoClient.connect "mongodb://#{@_host}:#{@_port}/#{_database}", (err, db) ->
      throw err if err

      @_debug "eachAsync: gettin cursor on database and collection"
      cursor = db
        .collection(collection)
        .find()

      if skip?
        @_debug "eachSync: skipping #{skip} results of collection"
        cursor = cursor.skip skip

      if limit?
        @_debug "eachSync: limiting #{limit} results of collection"
        cursor = cursor.limit limit

      cursor = cursor
        .batchSize(@_batchSize)

      # this function is closure-safe (we could put it outside in a library)
      _readCursor = (cursor, i, delay, db, next) =>
        cursor.nextObject (err, item) =>
          @_debug "eachAsync:_readCursor: cursor.nextObject(function(err, item){})"
          throw err if err
          if item
            @_debug "                          - returned an item"
            cb item, yes
            fn = -> next(cursor, i+1, delay)
            setTimeout fn, delay
          else
            @_debug "                          - returned nothing: end reached"
            cb undefined, yes
            db.close()

      @_debug "eachAsync: calling _readCursor(cursor, 0, delay, db, next)"
      _readCursor(cursor, 0, delay, db, _readCursor)
    return undefined

module.exports = Mongo
