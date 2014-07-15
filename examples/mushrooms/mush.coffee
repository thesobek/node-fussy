Fussy = require 'fussy'
Lazy = require 'lazy'


db = Fussy
  .debug  no            # debug mode (warning: very verbose)
  .input  'test.csv'    # input file
  .schema 'schema.json' # define the data schema
  .skip   0             # ignore N first items
  .limit  50            # limit to N first items

query = db
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


console.log "example using repair, with no callback"
console.log Fussy.pretty db.repair
  'edible': undefined
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
