"use strict"

chai = require 'chai'
should = chai.should()
expect = chai.expect

Fussy = require 'fussy'

echo = (x) -> console.log Fussy.pretty x

#describe 'solving a simple problem', ->

#  it 'should return the result synchronously', ->
do ->
  do ->
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

    result = db.solve
      age: 18
      category: undefined


    # should be left untouched
    result.age.should.be.within(17 - 0.001, 20 + 0.001)
    result.category.should.equal 'student' # should be set

    ###
    will print: { age: 18, category: 'student' }
    ###
    
    [res1, res2] = db.solve [
      { age: 18, category: undefined }
      { age: 14, category: undefined }
    ]

    echo res1
    echo res2
