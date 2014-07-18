
chai = require 'chai'
should = chai.should()
expect = chai.expect

Fussy = require 'fussy'

echo = (x) -> console.log Fussy.pretty x

Fussy.debug no

db = Fussy [
  { age: 5,  category: 'children'   }
  { age: 15, category: 'pupil'      }
  { age: 17, category: 'student'    }
  { age: 18, category: 'student'    }
  { age: 18, category: 'worker'     }
  { age: 20, category: 'student'    }
  { age: 23, category: 'worker'     }
  { age: 25, category: 'worker'     }
  { age: 30, category: 'worker'     }
]

query = db.query
  select: 'age'
  where:
    category: 'pupil'

result = query.all()


expected =
  age: [
    [ 15, 1000000 ]
     [ 18, 2 ]
     [ 5, 1 ]
     [ 17, 1 ]
     [ 20, 1 ]
     [ 23, 1 ]
     [ 25, 1 ]
     [ 30, 1 ]
    ]

result.should.deep.equal expected
