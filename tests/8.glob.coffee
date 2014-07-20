chai = require 'chai'
should = chai.should()
expect = chai.expect

Fussy = require 'fussy'

echo = (x) -> console.log Fussy.pretty x

db = Fussy 'tests/data/profiles/*.json'

r = db

  .solve
    bio: 'hacker'
    sex: undefined

  .sex.should.equal 'female'

r = db

  .solve
    bio: 'cook'
    sex: undefined

  .sex.should.equal 'male'

###
db.solve
    bio: 'hacker'
    sex: undefined
  , (r) -> r.should.equal 'female'

db.solve
    bio: 'cook'
    sex: undefined
  , (r) -> r.should.equal 'male'
###
