"use strict"

chai = require 'chai'

###
First you need to load the library
###
Fussy = require 'fussy'


# the basic usage for Fussy is to use it on a collection of JSONs
data = [
  { foo: 'bar' }
  { bar: 'foo' }
]

# just call the input function on it
db = Fussy(data)

#console.log Fussy.pretty db.solve()
