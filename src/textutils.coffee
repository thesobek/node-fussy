
exports.replaceAll = (find, replace, str) ->
   str.replace(new RegExp(find, 'g'), replace)


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

exports.ngramize = (words, n) -> 
  ngrams = {}
  for ngram in Object.keys _ngramize words, n
    # small ngrams are weaker than big ones
    splitted = ngram.split ","
    ngrams[splitted.join(" ").toString()] = 1 # (splitted.length / n)
  ngrams

NUMERIC_KEYPOINTS = [
  10, 20, 30, 40, 50, 60, 70, 80, 90,
  100, 200, 300, 400, 500, 600, 700, 800, 900,
  1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 
  10000
]
NUMERIC_KEYPOINTS_REVERSE = [
  10, 20, 30, 40, 50, 60, 70, 80, 90,
  100, 200, 300, 400, 500, 600, 700, 800, 900,
  1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 
  10000
].reverse()

exports.numerize = (sentence) ->
  numeric = {}
  for word in sentence.split " "
    test = (Number) word
    continue unless (not isNaN(test) and isFinite(test))

    for category in NUMERIC_KEYPOINTS
      if test < category
        numeric["less_than_#{category}"] = 1 # 0.5 # TODO compute some distance weight
        break

    for category in NUMERIC_KEYPOINTS_REVERSE
      if test > category
        numeric["more_than_#{category}"] = 1 # 0.5 # TODO compute some distance weight
        break
  numeric
  
exports.cleanContent = (content) -> 
  content = content.replace(/(&[a-zA-Z]+;|\\t)/g, ' ')
  content = content.replace(/(?:\.|\?|!|\:|;|,)+/g, '.')
  content = content.replace(/\s+/g, ' ')
  content = content.replace(/(?:\\n)+/g, '')
  content = content.replace(/\n+/g, '')
  content

exports.contentToSentences = (content) ->
  sentences = []
  for sent in content.split "."
    sent = sent.trim()
    if sent.length > 2
      sentences.push sent
  sentences
