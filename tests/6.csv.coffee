Fussy = require 'fussy'

echo = (x) -> console.log Fussy.pretty x

config =
  data:
    testUsers: 'tests/data/test-users.csv'

###
csv loaded like this will have (more or less) dynamic schemas
###

challenge =
  age: 18
  category: undefined

res = Fussy(config.data.testUsers)
  .skip(0)
  .solve challenge

res.age.should.be.within 17.999, 18.001
res.category.should.equal 'student'

Fussy(config.data.testUsers)
  .skip(0)
  .solve challenge, (res) ->

    res.age.should.be.within 17.999, 18.001
    res.category.should.equal 'student'


###
You can also pass a schema to map columns to json attributes, useful if you have
no header, or want better control over types
###

db = Fussy(config.data.testUsers)
  .skip(1)
  .schema [
      ['age', 'Number']
      ['category','String']
    ]

res = db.solve challenge


res.age.should.be.within 17.999, 18.001
res.category.should.equal 'student'


db._schema.should.deep.equal [
  [ 'age', 'Number' ]
  [ 'category', 'String' ]
]



db = Fussy(config.data.testUsers)
  .skip(1)
  .schema [
      ['age', 'Number']
      ['category','String']
    ]

db.solve challenge, (res) ->


  res.age.should.be.within 17.999, 18.001
  res.category.should.equal 'student'


  db._schema.should.deep.equal [
    [ 'age', 'Number' ]
    [ 'category', 'String' ]
  ]
