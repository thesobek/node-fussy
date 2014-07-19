"use strict"

# standard node library
path   = require 'path'
util   = require 'util'
Url    = require 'url'
fs     = require 'fs'
glob   = require 'glob'
stream    = require 'stream'
readline  = require 'readline'

# third party modules
mime      = require 'mime'
colors    = require 'colors'
csvString = require 'csv-string' # csv row parser

# our modules
utils   = require '../utils'

pretty = utils.pretty

class Glob
  constructor: (@_fussy, @_url) ->

    parsed = Url.parse @_url

    @_path = parsed.path

    if !parsed.protocol?
      @_path = @_url

  debug: (enabled) ->
    @_debugEnabled = enabled
    @

  _debug: (x) ->
    # use master debug setting, unless we overloaded it for our protocol
    return unless (if @_debugEnabled? then @_debugEnabled else @_fussy._debugEnabled)
    console.log "Glob".blue + "::".grey + x

  # actually, even if we are synchronous, we could do something smarter
  # using the low level file read (ie. only load the file chunk by chunk,
  # synchronously)
  eachSync: (cb) ->
    @_debug "eachSync(cb)"

    files = glob.sync @_path

    skip = @_fussy._skip ? 0
    limit = @_fussy._limit ? Infinity

    jsonFiles = []

    for file in files
      type = mime.lookup file

      if type is 'application/json'
        jsonFiles.push type

      else
        @_debug "eachSync: files of type #{type} are not supported in synchronous mode"

    i = 0

    jsonFiles = jsonFiles[skip...(skip+limit)]
    m = jsonFiles.length

    for jsonFile in jsonFiles

      obj = undefined
      try
        obj = JSON.parse fs.readFileSync file, 'utf8'
      catch exc
        @_debug "eachSync: couldn't read json file #{file}: #{exc}"
        continue

      if obj?
        cb obj, no
    cb undefined, yes


  eachAsync: (cb) ->
    @_debug "eachAsync(cb)"

    skip = @_fussy._skip ? 0
    limit = @_fussy._limit ? Infinity

    glob.sync @_path, (err, files) =>

      jsonFiles = []

      for file in files
        type = mime.lookup file

        if type is 'application/json'
          jsonFiles.push type

        else
          @_debug "eachAsync: files of type #{type} are not supported in synchronous mode"

      i = 0

      jsonFiles = jsonFiles[skip...(skip+limit)]
      m = jsonFiles.length
      for jsonFile in jsonFiles
        i++
        isLast = (i is m)
        do (jsonFile, isLast) =>
          fs.readFile schema, 'utf8', (err, data) =>
            if err
              @_debug "eachAsync: coudln't read JSON file: #{err}"
              cb undefined, isLast
            else
              obj = undefined
              try
                obj = JSON.parse data
              catch exc
                @_debug "eachAsync: couldn't read JSON file #{jsonFile}: #{exc}"
                cb undefined, isLast
                return
              cb obj, isLast


module.exports = Glob
