"use strict"

# standard node library
util   = require 'util'

# third party modules
mime      = require 'mime'
colors    = require 'colors'

# our modules
utils   = require '../utils'

pretty = utils.pretty

class List
  constructor: (@_fussy, @_list) ->

    unless utils.isArray @_list
      throw "Error: input is not an array!"

  debug: (enabled) ->
    @_debugEnabled = enabled
    @

  _debug: (x) ->
    # use master debug setting, unless we overloaded it for our protocol
    return unless (if @_debugEnabled? then @_debugEnabled else @_fussy._debugEnabled)
    console.log "List".blue + "::".grey + x
    
  eachSync: (cb) ->
    @_debug "eachSync"
    for item in @_list
      cb item, no
    cb undefined, yes
    return

  eachAsync: (cb) ->
    @_debug "eachAsync"

    for item in @_list
      cb item, no
    cb undefined, yes
    return


module.exports = List
