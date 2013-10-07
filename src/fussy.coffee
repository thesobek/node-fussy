fs        = require 'fs'
{pick}    = require 'deck'
{ngramize, numerize, cleanContent, contentToSentences} = require './textutils'
  
debug = ->

isString = (obj) -> !!(obj is '' or (obj and obj.charCodeAt and obj.substr))

P = (p=0.5) -> + (Math.random() < p)

POSITIVE = exports.POSITIVE = +1
NEGATIVE = exports.NEGATIVE = -1
NEUTRAL  = exports.NEUTRAL  = 0

emptyThesaurus = find: -> []


class Facets
  constructor: (opts={}) ->
    @facets = opts.facets ? {}
    @stringSize = opts.stringSize ? [0, 30]
    @network = opts.network ? {}

  put: (facet, weight=1) ->
    if @stringSize[0] < facet.length < @stringSize[1]
      @facets[facet] = 1 #weight + (@facets[facet] ? 0)
    @

  resonate: (times=5) ->
    for i in [0...times]
      debug " - resonate #{i}"
      for facet_a, weight_a of @facets
        facet_a = facet_a.toLowerCase()
        for facet_b, weight_b of @network[facet_a] ? {}
          @facets[facet_b] = weight_a * weight_b  + (@facets[facet_b] ? 0)
    @

  explore: (times=5) ->
    for i in [0...times]
      #ebug " - explore #{i}"
      for facet_a, weight_a of @facets
        facet_a = facet_a.toLowerCase()
        for facet_b, weight_b of @network[facet_a] ? {}
          @facets[facet_b] = 1
    @

  dump: ->
    @facets

class exports.Engine
  constructor: (opts={}) ->
    if isString opts
      debug "loading '#{opts}'.."
      opts = JSON.parse fs.readFileSync opts, 'utf8'
    @stringSize = opts.stringSize ? [0, 30]
    @ngramSize  = opts.ngramSize ? 3
    @debug      = opts.debug ? no
    @sampling   = opts.sampling ? 0.3
    debug       = if @debug then console.log else ->
    @profiles   = opts.profiles ? {}
    @network    = opts.network ? {}
    @database   = do -> 
      uri = opts.database ? "://"
      [backend, params] = uri.split "://"
      if backend is 'redis'
        debug "redis not supported yet, but no big deal."



  # magic function that does everything
  extractFacetsFromRawContent: (raw) ->

    sentences = contentToSentences cleanContent raw

    facets = new Facets
      stringSize: @stringSize
      network: @network

    for sentence in sentences
      for facet, weight of ngramize sentence, @ngramSize
        facets.put facet, weight

      for facet, weight of numerize sentence
        facets.put facet, weight

    # resonate N times
    #facets.resonate 3
    facets.explore 3
 
    facets.dump()

  store: (event) ->

    if event.signal is NEUTRAL
      debug "signal is neutral, ignoring"
      return

    # analyze the content
    if !@profiles[event.profile]?
      debug "creating profile for #{event.profile}"
      @profiles[event.profile] = {}

    profile = @profiles[event.profile]

    debug "updating profile #{event.profile}.."

    # new sum
    for facet, weight of @extractFacetsFromRawContent event.content
      profile[facet] = event.signal * weight + (profile[facet] ? 0)
    
    @

  # lighten the database, removing weak connections (neither strongly positive or negative)
  prune: (min, max) ->
    for profile, facets of @profiles
      for facet, _ of facets
        facets[facet] = facets[facet] - 1
        if min < facets[facet] < max
          delete facets[facet]
    @

  # search for profiles matching a given content,
  # and evaluate them
  # you can optionally limit the number of results to the first N,
  # using the {limit: N} parameter,
  # or filter result to a restricted list of profiles using {profiles: ["some_id"]}
  rateProfiles: (content, opts={}) ->
    filter = opts.profiles ? []
    limit = opts.limit
    results = []

    facets = @extractFacetsFromRawContent content
    
    for id, profile of @profiles
      continue if filter.length and id not in filter
      score = 0
      for facet, weight of facets
        score += weight * (profile[facet] ? 0)
      results.push [id, score]

      continue unless limit?
      break if --limit <= 0

    results.sort (a, b) -> b[1] - a[1]
    results

  # rate an array of contents for a given profile id,
  # sorting results from best match to worst
  rateContents: (id, contents) ->
    profile = @profiles[id] ? {}

    top = []
    id = 0
    for content in contents
      score = 0
      for facet, weight of @extractFacetsFromRawContent content
        score += weight * (profile[facet] ? 0)
      top.push [content, score]
    top.sort (a, b) -> b[1] - a[1]
    top

  save: (filePath) ->
    throw "Error, no file path given" unless filePath?
    # the code is written using appendFileSync, this is not pretty
    # but when exporting huge database it allows us to see the progression line by line
    # eg. using "watch ls -l" or "tail -f file.json" on unix
    write = (x) -> fs.appendFileSync filePath, x.toString() + '\n'
    #write = (x) -> console.log "#{x}"
    fs.writeFileSync filePath, '{\n' # first line is in write-mode
    write """  "stringSize": [#{@stringSize}],"""
    write """  "ngramSize": #{@ngramSize},"""
    write """  "profiles": {"""

    remaining_profiles = Object.keys(@profiles).length # not efficient?
    for profile, facets of @profiles
      write """    "#{profile}": {"""
      remaining_facets = Object.keys(facets).length # not efficient?
      for facet, weight of facets
        write """      "#{facet}": #{weight}#{if --remaining_facets > 0 then ',' else ''}"""
      write """    }#{if --remaining_profiles > 0 then ',' else ''}"""
    write """  }\n}"""


