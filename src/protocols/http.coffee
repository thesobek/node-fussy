"use strict"

# standard node library
util   = require 'util'
Url    = require 'url'

# third party modules
mime      = require 'mime'
colors    = require 'colors'
csvString = require 'csv-string' # csv row parser

# async http
request   = require 'request'

# sync http
httpsync = require 'httpsync'

# our modules
utils   = require '../utils'

pretty = utils.pretty

class Http
  constructor: (@_fussy, @_url) ->

  debug: (enabled) ->
    @_debugEnabled = enabled
    @

  _debug: (x) ->
    # use master debug setting, unless we overloaded it for our protocol
    return unless (if @_debugEnabled? then @_debugEnabled else @_fussy._debugEnabled)
    console.log "Http".blue + "::".grey + x

  eachSync: (cb) ->
    @_debug "eachSync: http get #{@_url}"
    res = httpsync.get @_url
    body = res.data.toString 'utf8'
    @_debug "eachSync: result: #{body}"

    type = mime.lookup path
    switch type
      when 'text/csv'
        @_debug "eachSync: downloaded file is a #{type}"
        lines = body.split '\n'
        for line in lines
          cb line, no
        cb undefined, yes
      else
        @_debug "eachSync: request: unrecognized file format"
        cb undefined, yes
    return

  eachAsync: (cb) ->

    @_debug "eachAsync: calling request"

    url = @_url
    parsed = Url.parse url
    path = parsed.path

    request @_url, (error, response, body) =>
      if !error and response.statusCode is 200
        @_debug "eachAsync: request: succeeded"
        type = mime.lookup path
        switch type
          when 'text/csv'
            @_debug "eachAsync: request: downloaded content is a #{type}"
            lines = body.split '\n'
            for line in lines
              cb line, no
            cb undefined, yes
          else
            @_debug "eachAsync: request: unrecognized file format"
            cb undefined, yes

      else
        @_debug "eachAsync: request: failed: #{error}"
        cb undefined, yes
    return

module.exports = Http
