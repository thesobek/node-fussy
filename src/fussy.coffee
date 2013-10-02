fs        = require 'fs'
{pick}    = require 'deck'

debug = ->

isString = (obj) -> !!(obj is '' or (obj and obj.charCodeAt and obj.substr))

P = (p=0.5) -> + (Math.random() < p)

replaceAll = (find, replace, str) ->
   str.replace(new RegExp(find, 'g'), replace)

POSITIVE = exports.POSITIVE = +1
NEGATIVE = exports.NEGATIVE = -1
NEUTRAL  = exports.NEUTRAL  = 0

emptyThesaurus = find: -> []

# Extract n-grams from a string, returns a map
_ngramize = (words, n) ->
  unless Array.isArray words
    words = for w in words.split ' '
      continue if w.length < 3
      w

  grams = {}
  if n < 2
    for w in words
      grams["#{w}"] = if Array.isArray(w) then w else [w]
    return grams
  for i in [0...words.length]
    gram = words[i...i+n]
    subgrams = _ngramize gram, n - 1
    for k,v of subgrams
      grams[k] = v
    if i > words.length - n
      break
    grams["#{gram}"] = gram
  grams

ngramize = (words, n) -> 
  ngrams = {}
  for ngram in Object.keys _ngramize words, n
    # small ngrams are weaker than big ones
    ngrams[ngram.split(",").sort().toString()] = (ngram.length / n)
  ngrams
  
numerize = (sentence) ->
  numeric = {}
  for word in sentence.split " "
    test = (Number) word
    continue unless (not isNaN(test) and isFinite(test))

    categories = [
      10, 20, 30, 40, 50, 60, 70, 80, 90,
      100, 200, 300, 400, 500, 600, 700, 800, 900,
      1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 
      10000
    ]
    for category in categories
      if test < category
        numeric["less_than_#{category}"] = 0.5 # TODO compute some distance weight
        break

    for category in categories.reverse()
      if test > category
        numeric["more_than_#{category}"] = 0.5 # TODO compute some distance weight
        break
  numeric
  
cleanContent = (content) -> 
  content = content.replace(/(&[a-zA-Z]+;|\\t)/g, ' ')
  content = content.replace(/(?:\.|\?|!)+/g, '.')
  content = content.replace(/\s+/g, ' ')
  content = content.replace(/(?:\\n)+/g, '')
  content = content.replace(/\n+/g, '')
  content

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


  # magic function that does everything
  extractFacetsFromRawContent: (raw) ->

    content = cleanContent raw

    ngrams = {}

    for k,v of ngramize content, @ngramSize
      ngrams[k] = v

    for k,v of numerize content
      ngrams[k] = v

    facets = {}
    for ngram, ngram_weight of ngrams
      word = ngram.split(',').join(' ')
      # filter
      continue unless @stringSize[0] < word.length < @stringSize[1]

      if word of @network
        for synonym, synonym_weight of @network[word]
          continue if synonym of facets # but here we do not overwrite ngrams!
          facets[synonym] = ngram_weight * synonym_weight
       
      facets[word] = ngram_weight # this will overwrite synonyms, if any, but we don't care
    facets

  pushEvent: (event) ->

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


