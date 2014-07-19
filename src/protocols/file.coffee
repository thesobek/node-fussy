"use strict"

# standard node library
path   = require 'path'
util   = require 'util'
Url    = require 'url'
fs     = require 'fs'

# third party modules
mime      = require 'mime'
colors    = require 'colors'
csvString = require 'csv-string' # csv row parser


# our modules
utils   = require '../utils'

pretty = utils.pretty

class File
  constructor: (@_fussy, @_url) ->

    parsed = Url.parse @_url

    @_path = parsed.path

    if !parsed.protocol?
      @_path = @_url

    @_mimetype = mime.lookup @_path

  debug: (enabled) ->
    @_debugEnabled = enabled
    @

  _debug: (x) ->
    # use master debug setting, unless we overloaded it for our protocol
    return unless (if @_debugEnabled? then @_debugEnabled else @_fussy._debugEnabled)
    console.log "File".blue + "::".grey + x

  # actually, even if we are synchronous, we could do something smarter
  # using the low level file read (ie. only load the file chunk by chunk,
  # synchronously)
  eachSync: (cb) ->
    @_debug "eachSync(cb)"

    unless @_mimetype is 'text/csv'
      throw "files of type #{@_mimetype} are not supported in synchronous mode"

    str = fs.readFileSync @_path, 'utf8'
    lines = str.split('\n')
    skip = @_fussy._skip ? 0
    limit = @_fussy._limit ? Infinity

    for line in lines[skip...(skip+limit)]
      cb line, no

    cb undefined, yes
    return


  eachAsync: (cb) ->
    @_debug "eachAsync(cb)"

    skip = @_fussy._skip ? 0
    limit = @_fussy._limit ? Infinity

    _readInputStream = (instream, cb) =>
      outstream = new (require 'stream')
      rl = require('readline').createInterface instream, outstream

      i = 0
      rl.on 'line', (line) ->
        i += 1
        if i <= skip
          return
        if i < (skip + limit)
          cb line, no
        else
          @debug "todo: stop read stream"

      rl.on 'close', ->
        cb undefined, yes

    switch @_mimetype

      # TODO we should use this instead, because it supports more formats:
      # https://github.com/atom/node-ls-archive

      when 'application/zip'
        @_debug "eachAsync: opening #{@_mimetype} file"
        fs
          .createReadStream @_path
          .pipe unzip.Parse()
          .on 'entry', (entry) =>
            @_debug "eachAsync: inside the #{@_mimetype} I found this: #{entry.path}"
            if entry.type is 'File'
              type = mime.lookup entry.path
              switch type
                when 'text/csv'
                  @_debug "eachAsync: inside the #{@_mimetype} I found some #{type}"
                  _readInputStream entry, cb
                  return
            @_debug "eachAsync: ignoring file #{entry.path} by draining the input stream"
            entry.autodrain()

      when 'text/csv'
        @_debug "eachAsync: reading text/csv file"
        instream = fs.createReadStream @_path
        _readInputStream instream, cb
      else
        thro "files of type #{@_mimetype} are not supported in asynchronous mode"

    return undefined

module.exports = File
