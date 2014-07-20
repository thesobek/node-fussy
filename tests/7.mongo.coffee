chai = require 'chai'
should = chai.should()
expect = chai.expect


Fussy = require 'fussy'

echo = (x) -> console.log Fussy.pretty x

describe 'using the MongoDB protocol', ->

  challenge =
    bio: 'hacker'
    sex: undefined

  db = Fussy 'mongodb://127.0.0.1:27017/fussy/test1'

  it 'should work on the solve method in async', ->

    db.solve challenge, (res) ->
      res.sex.should.equal 'female'
