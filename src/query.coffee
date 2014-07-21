"use strict"

# standard node library
util   = require 'util'

# third party modules
colors    = require 'colors'
deck      = require 'deck'

# our modules
utils   = require './utils'
text    = require './text'

pretty = utils.pretty

class Query
  constructor: (@_fussy, queries, isSingle) ->
    @_error = undefined
    @_mode = 'all'
    @_isSingle = isSingle

    @_queries = for q in queries
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

      q

  debug: (enabled) ->
    @_debugEnabled = enabled
    @

  _debug: (x) ->
    # use master debug setting, unless we overloaded it for our protocol
    return unless (if @_debugEnabled? then @_debugEnabled else @_fussy._debugEnabled)
    console.log "Query".green + "::".grey + x


  _reduceFn: (requests, features) ->
    @_debug "reduceFn(requests, features)" +" // deep comparison".grey
    unless features?
      @_debug "reduceFn: end condition"
      return requests

    for request in requests

      weight = 0
      factors = []

      nb_feats = 0
      #@_debug "request.query.where: "+pretty request.query.where

      for where in request.query.where
        #@_debug "where: " + pretty where
        depth = 0
        complexity = 0

        for [type, key, value] in features

          #@_debug [type, key, value]

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
                  @_debug "type #{type} not supported"

            if match
              nb_feats += 1

        # these parameters depends on the plateform
        depth *= Math.min 6, 300 / nb_feats
        weight += 10 ** Math.min 300, depth

      for [type, key, value] in features
        #@_debug "key: "+key

        if request.query.select?
          unless key of request.query.select
            continue

        #@_debug "here"
        unless key of request.types
          request.types[key] = type

        # TODO put the 4 following lines before the "continue unless"
        # if you want to catch all results
        unless key of request.result
          request.result[key] = {}

        unless value of request.result[key]
          request.result[key][value] = 0

        #@_debug "match for #{key}: #{query.select[key]}"

        match = no
        if request.query.select?
          if utils.isArray request.query.select[key]
            #@_debug "array"
            if request.query.select[key].length
              if value in request.query.select[key]
                #@_debug "SELECT match in array!"
                match = yes
            else
              #@_debug "empty"
              match = yes
          else
            #@_debug "not array"
            if value is request.query.select[key]
              #@_debug "SELECT match single value!"
              match = yes
        else
          match = yes

        if match
          request.result[key][value] += weight

    @_debug "_reduceFn: reducing"
    #@_debug pretty requests
    return requests


  _toBestFn: (inputs, cb) ->
    @_debug "_toBestFn(inputs)"

    outputs = for input in inputs
      {result, types} = input
      output = {}
      for key, options of result
        @_debug "_toBestFn: #{key}: #{pretty options}"
        isNumerical = types[key] is 'Number'

        if isNumerical
          #@_debug "isNumerical"
          sum = 0
          for option, weight of options
            sum += weight

          output[key] = 0
          for option, weight of options
            option = (Number) option
            #@_debug "option: #{option}, weight: #{weight}, sum: #{sum}"
            #@_debug "A output[key]: #{pretty output[key]}"
            if sum > 0
              #@_debug "sum: #{sum}"
              ws = weight / sum
              output[key] += option * ws
            else
              #@_debug "weight: #{weight}"
              output[key] += option * weight
            #@_debug "B output[key]: #{pretty output[key]}"

        else
          output[key] = []
          for option, weight of options
            if types[key] is 'Boolean'
              option = (Boolean) option
            output[key].push [option, weight]
          output[key].sort (a,b) -> b[1] - a[1]
          best = output[key][0] # get the best
          output[key] = best[0] # get the value
      output

    if cb?
      cb outputs
      return undefined
    else
      return outputs


  # convert a key:{ opt_a:3, opt_b: 4}
  _toAllFn: (requests, cb) ->

    @_debug "_toAllFn(requests, cb?)"+"  // cast output map to typed array"

    __toAllFn = =>
      @_debug "_toAllFn:__toAllFn()"
      # note: we remplace list elements inline to avoid useless copies
      for request in requests
        for key, options of request.result
          sorted = []
          if request.types[key] is 'Number'
            @_debug "_toAllFn:__toAllFn: Number -> #{key}"
            for option, weight of options
              #@_debug "_toAllFn:__toAllFn: [#{key}, #{(Number) option}, #{weight}]"
              sorted.push [((Number) option),  weight]
              #@_debug "pushed: #{all}"

          else if request.types[key] is 'Boolean'
            @_debug "_toAllFn:__toAllFn: Boolean -> #{key}"
            for option, weight of options
              #@_debug "_toAllFn:__toAllFn: [#{key}, #{(Number) option}, #{weight}]"
              sorted.push [((Boolean) option), weight]
          else
            @_debug "_toAllFn:__toAllFn: String -> #{key}"
            for option, weight of options
              #@_debug "_toAllFn:__toAllFn: [#{key}, #{(Number) option}, #{weight}]"
              sorted.push [option, weight]

          request.result[key] = sorted.sort (a,b) -> b[1] - a[1]
        return
      return #
      #requests

    if cb?
      __toAllFn()
      cb requests
      return undefined
    else
      __toAllFn()
      return requests


  trigger: (cb) -> if cb? then @_async(cb) else @_sync()

  all: (cb) ->
    @_debug "all(cb?)"
    @_mode = 'all'
    @trigger cb

  best: (cb) ->
    @_debug "mix(cb?)"
    @_mode = 'best'
    @trigger cb

  replace: (cb) ->
    @_debug "replace(cb?)"
    @_mode = 'replace'
    @trigger cb

  pick: (n, cb) ->
    @_debug "pick(#{n}, cb?)"
    @_mode = 'pick'
    @_pick_instances = n
    @trigger cb

  generate: (cb) ->
    @_debug "generate(cb?)"
    @_mode = 'generate'
    @trigger cb

  # toArray = get sync
  _sync: ->
    @_debug "_sync()"

    unless @_queries.length > 0
      throw "error, no query is empty"

    requests = for query in @_queries
      query: query
      result: {}
      types: {}

    @_debug "_sync: @_fussy.eachFeatureSync:"
    @_fussy.eachFeaturesSync (features, isLastItem) =>
      @_debug "_sync: @_fussy.eachFeatureSync(#{pretty features}, #{pretty isLastItem})"
      requests = @_reduceFn requests, features

    output = switch @_mode
      when 'all'
        @_debug "_sync: all: @_toAllFn()"
        @_toAllFn requests

      when 'pick'
        @_debug "_sync: pick"

        res = for i in [0...@_pick_instances]
          firstRequest = requests[0]
          picked = {}
          for key, options of firstRequest.result
            #@_debug pretty options
            option = deck.pick options
            picked[key] = option
          picked

        if utils.isArray res
          if res.length is 1
            res = res[0]
        res

      when 'generate'
        @_debug "_sync: generate"
        =>
          firstRequest = requests[0]
          generated = {}
          for key, options of firstRequest.result
            generated[key] = deck.pick options
          generated

      when 'best'
        @_debug "_sync: best: @_toBestFn(#{pretty requests})"
        @_toBestFn requests

      when 'replace'
        @_debug "_sync: fix: @_toBestFn(#{pretty requests})"
        results = @_toBestFn requests

        replaced = for request in requests

          for k,v of result
            if !request.query.replace[k]?
              request.query.replace[k] = v

          request.query.replace

        replaced

    @_debug "_sync: return #{pretty output}"
    output

  onError: (cb) ->
    @_debug "onError(cb)"
    @_onError = cb

  # onComplete = get async
  _async: (cb) ->

    @_debug "_async(cb)"

    unless @_queries.length > 0
      throw "error, no query is empty"

    requests = for query in @_queries
      query: query
      result: {}
      types: {}

    @_debug "_async: @_fussy.eachFeatureAsync:"
    @_fussy.eachFeaturesAsync (features, isLastItem) =>
      @_debug "_async: @_fussy.eachFeatureAsync(#{pretty features}, #{pretty isLastItem})"

      @_debug "_async: @_reduceFn(requests, features)"
      results = @_reduceFn requests, features
      return unless isLastItem
      @_debug "_async: isLastItem == true"

      switch @_mode
        when 'all'

          @_debug "_async: all: @_toAllFn(requests, cb)"
          @_toAllFn requests, (results) =>

            @_debug "_async: all: cb(results)"
            cb results

        when 'pick'
          @_debug "_sync: pick"
          res = for i in [0...@_pick_instances]
            firstRequest = requests[0]
            picked = {}
            for key, options of firstRequest.result
              #@_debug pretty options
              option = deck.pick options
              picked[key] = option
            picked

          if utils.isArray res
            if res.length is 1
              res = res[0]
          cb res

        when 'generate'
          @_debug "_async: generate"
          cb =>
            firstRequest = requests[0]
            generated = {}
            for key, options of firstRequest.result
              generated[key] = deck.pick options
            generated

        when 'best'
          @_debug "_async: best: @_toBestFn(#{pretty requests})"
          @_toBestFn requests, (bests) =>

            @_debug "_async: best: cb(bests)"
            cb bests

        when 'replace'
          @_debug "_async: replace: @_toBestFn(#{pretty requests})"
          @_toBestFn requests, (results) =>
            @_debug "_async: replace: @_toBestFn: results: #{pretty results}"
            replaced = for request in requests

              for k,v of results
                if !request.query.replace[k]?
                  request.query.replace[k] = v
              request.query.replace

            cb replaced


    return undefined

module.exports = Query
