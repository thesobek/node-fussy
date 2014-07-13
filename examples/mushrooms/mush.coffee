Fussy = require 'fussy'
Lazy = require 'lazy'

data = [
  "p,x,s,n,t,p,f,c,n,k,e,e,s,s,w,w,p,w,o,p,k,s,u"
  "e,x,s,y,t,a,f,c,b,k,e,c,s,s,w,w,p,w,o,p,n,n,g"
  "e,b,s,w,t,l,f,c,b,n,e,c,s,s,w,w,p,w,o,p,n,n,m"
]

db = Fussy
  .database 'test.csv'    # input file
  .schema   'schema.json' # define the data schema
  .skip     1             # ignore N first items
  .limit    3             # limit to N first items

db
  .query                # run a query
    select: 'edible'    # which value we want to show in the end
    where:
      #edible: 't'     # do not cheat!
      'cap-shape': 'convex'
      'cap-surface': 'scaly'
      'cap-color': 'yellow'
      'bruises?': 'bruises'
      'odor': 'almond'
      'gill-attachment': 'free'
      'gill-spacing': 'close'
      'gill-size': 'broad'
      'gill-color': 'brown'
      'stalk-shape': 'enlarging'
      'stalk-root': 'club'
      'stalk-surface-above-ring': 'smooth'
      'stalk-surface-below-ring': 'smooth'
      'stalk-color-above-ring': 'white'
      'stalk-color-bellow-ring': 'white'
      'veil-type': 'partial'
      'veil-color': 'white'
      'ring-number': 'one'
      'ring-type': 'pendant'
      'spore-print-color': 'black'
      'population': 'numerous'
      'habitat': 'grasses'
  .get (result) ->
    console.log "result: " + Fussy.pretty result
  #.each (item) ->
  #  console.log("item: "+JSON.stringify(item))
