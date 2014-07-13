utils = require './utils'

###
Extract features from a JSON object
###
extract = (event, facts=[], prefix="") ->
  
  #console.log "extracting features from: #{JSON.stringify event}"
  ###
  This was supposed to be a built-in support for a "date" attribute
  TODO but it is a bit awkward: we should rather use the schema for that.
  let's disable it for now.
  ###
  #if facts.length is 0
  #  if event.date?
  #    facts.push ['Date', 'date', moment(event.date).format()]
  #    delete event['date']

  try
    for key, value of event

      key = prefix + key
      #console.log "key: #{key}"

      # TODO we should use in priority the schema for this, then only detect type
      # as a fallback

      if utils.isString value
        #console.log "String"
        facts.push ['String', key, value]

      else if utils.isArray value
        #console.log "Array"
        facts.push ['Array', key, value]

      else if utils.isNumber value
        #console.log "Number"
        facts.push ['Number', key, value]

      else if utils.isBoolean value
        #console.log "Boolean"
        facts.push ['Boolean', key, value]

      else
        #console.log "recursive"
        extract value, facts, key + "." # recursively flatten nested features
  catch exc
    console.log "failed: "+exc
    console.log exc

  #console.log "facts: " + JSON.stringify facts
  facts

module.exports = extract
