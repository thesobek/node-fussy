Fussy = require 'fussy'

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
