Fussy = require 'fussy'

echo = (x) -> console.log Fussy.pretty x

config =
  data:
    testUsers: 'tests/data/test-users.csv'

###
csv loaded like this will have (more or less) dynamic schemas
###
echo Fussy(config.data.testUsers).skip(1).solve age: 18, category: undefined

###
will print: { age: 18, category: 'student' }
###



###
You can also pass a schema to map columns to json attributes, useful if you have
no header, or want better control over types
###
db = Fussy(config.data.testUsers).skip(1).schema [
  ['age', 'Number']
  ['category','String']
]

echo db.solve
  age: 18
  category: undefined
