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
  constructor: (@_fussy, q) ->
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

    @_query = q

  debug: (enabled) ->
    @_debugEnabled = enabled
    @

  _debug: (x) ->
    # use master debug setting, unless we overloaded it for our protocol
    return unless (if @_debugEnabled? then @_debugEnabled else @_fussy._debugEnabled)
    console.log "Query".green + "::".grey + x


  _reduceFn: (reduction, features) ->
    @_debug "reduceFn(reduction, features)" +" // deep comparison".grey
    unless features?
      @_debug "reduceFn: end condition"
      return reduction

    query = reduction.query
    #@_debug "reduction: " + pretty reduction
    #@_debug "features: "+pretty features

    weight = 0
    factors = []

    nb_feats = 0
    #@_debug "query.where: "+pretty where

    for where in query.where
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

      if query.select?
        unless key of query.select
          continue

      #@_debug "here"
      unless key of reduction.types
        reduction.types[key] = type

      # TODO put the 4 following lines before the "continue unless"
      # if you want to catch all results
      unless key of reduction.result
        reduction.result[key] = {}

      unless value of reduction.result[key]
        reduction.result[key][value] = 0


      #@_debug "match for #{key}: #{query.select[key]}"

      match = no
      if query.select?
        if utils.isArray query.select[key]
          #@_debug "array"
          if query.select[key].length
            if value in query.select[key]
              #@_debug "SELECT match in array!"
              match = yes
          else
            #@_debug "empty"
            match = yes
        else
          #@_debug "not array"
          if value is query.select[key]
            #@_debug "SELECT match single value!"
            match = yes
      else
        match = yes

      if match
        reduction.result[key][value] += weight

    @_debug "_reduceFn: reducing"
    #@_debug pretty reduction
    return reduction


  _toBestFn: (args, cb) ->
    @_debug "_toBestFn(args)"
    {result, types} = args

    output = {}
    for key, options of result
      isNumerical = types[key] is 'Number'

      if isNumerical

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

    @_debug "_toAllFn(args, cb?)"+"  // cast output map to typed array"

    __toAllFn = (_args) =>
      @_debug "_toAllFn:__toAllFn()"

      for key, options of _args.result
        sorted = []
        if _args.types[key] is 'Number'
          @_debug "_toAllFn:__toAllFn: Number -> #{key}"
          for option, weight of options
            #@_debug "_toAllFn:__toAllFn: [#{key}, #{(Number) option}, #{weight}]"
            sorted.push [((Number) option),  weight]
            #@_debug "pushed: #{all}"

        else if _args.types[key] is 'Boolean'
          @_debug "_toAllFn:__toAllFn: Boolean -> #{key}"
          for option, weight of options
            #@_debug "_toAllFn:__toAllFn: [#{key}, #{(Number) option}, #{weight}]"
            sorted.push [((Boolean) option), weight]
        else
          @_debug "_toAllFn:__toAllFn: String -> #{key}"
          for option, weight of options
            #@_debug "_toAllFn:__toAllFn: [#{key}, #{(Number) option}, #{weight}]"
            sorted.push [option, weight]

        _args.result[key] = sorted.sort (a,b) -> b[1] - a[1]

      _args.result

    if cb?
      result = __toAllFn args
      cb result
      return undefined
    else
      result = __toAllFn args
      return result


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

    ctx =
      query: @_query
      result: {}
      types: {}

    @_debug "_sync: @_fussy.eachFeatureSync:"
    @_fussy.eachFeaturesSync (features, isLastItem) =>
      @_debug "_sync: @_fussy.eachFeatureSync(#{pretty features}, #{pretty isLastItem})"
      ctx = @_reduceFn ctx, features

    results = switch @_mode
      when 'all'
        @_debug "_sync: all: @_toAllFn()"
        @_toAllFn ctx

      when 'pick'
        @_debug "_sync: pick"
        res = for i in [0...@_pick_instances]
          obj = {}
          for key, options of ctx.result
            #@_debug pretty options
            option = deck.pick options
            obj[key] = option
          obj

        if utils.isArray res
          if res.length is 1
            res = res[0]
        res

      when 'generate'
        @_debug "_sync: generate"
        =>
          obj = {}
          for key, options of ctx.result
            #@_debug pretty options
            option = deck.pick options
            obj[key] = option
          obj

      when 'best'
        @_debug "_sync: best: @_toBestFn(#{pretty ctx})"
        @_toBestFn ctx

      when 'replace'
        @_debug "_sync: fix: @_toBestFn(#{pretty ctx})"
        result = @_toBestFn ctx

        obj = ctx.query.replace
        for k,v of result
          if !obj[k]?
            obj[k] = v
        obj



    @_debug "_sync: return #{pretty results}"
    results

  onError: (cb) ->
    @_debug "onError(cb)"
    @_onError = cb

  # onComplete = get async
  _async: (cb) ->

    @_debug "_async(cb)"


    ctx =
      query: @_query
      result: {}
      types: {}

    @_debug "_async: @_fussy.eachFeatureAsync:"
    @_fussy.eachFeaturesAsync (features, isLastItem) =>
      @_debug "_async: @_fussy.eachFeatureAsync(#{pretty features}, #{pretty isLastItem})"

      @_debug "_async: @_reduceFn(ctx, features)"
      ctx = @_reduceFn ctx, features
      return unless isLastItem
      @_debug "_async: isLastItem == true"

      switch @_mode
        when 'all'

          @_debug "_async: all: @_toAllFn(ctx, cb)"
          @_toAllFn ctx, (results) =>

            @_debug "_async: all: cb(results)"
            cb results

        when 'pick'
          @_debug "_sync: pick"
          res = for i in [0...@_pick_instances]
            obj = {}
            for key, options of ctx.result
              #@_debug pretty options
              option = deck.pick options
              obj[key] = option
            obj
          if utils.isArray res
            if res.length is 1
              res = res[0]
          cb res

        when 'generate'
          @_debug "_async: generate"
          cb =>
            obj = {}
            for key, options of ctx.result
              #@_debug pretty options
              option = deck.pick options
              obj[key] = option
            obj

        when 'best'
          @_debug "_async: best: @_toBestFn(#{pretty ctx})"
          @_toBestFn ctx, (results) =>

            @_debug "_async: best: cb(results)"
            cb results

        when 'replace'
          @_debug "_async: replace: @_toBestFn(#{pretty ctx})"
          @_toBestFn ctx, (results) =>
            @_debug "_async: replace: @_toBestFn: results: #{pretty results}"
            obj = ctx.query.replace
            for k,v of results
              if !obj[k]?
                obj[k] = v
            obj
            cb obj


    return undefined

module.exports = Query
