Fussy = require 'fussy'

echo = (x) -> console.log Fussy.pretty x

###
pick() returns the missing attributes, by generating them using probabilities

thus it may returns different results if you call it multiple times
(or if you pass an integer as second parameter, which is the number of instances
to generate)

pitfall: for the moment, it generates each attribute independently, which means
generates items might not be consistent (eg. if you call the pick function using
age and category both set to 'undefined', you might get objects such as
age: 5, category: 'worker' more often than what it should be)
In the future I will try to code a recursive version, so that values will
be constrained together
###
echo Fussy([
  { age: 5,  category: 'children'   }
  { age: 15, category: 'pupil'      }
  { age: 17, category: 'student'    }
  { age: 18, category: 'student'    }
  { age: 18, category: 'worker'     }
  { age: 20, category: 'student'    }
  { age: 23, category: 'worker'     }
  { age: 25, category: 'worker'     }
  { age: 30, category: 'worker'     }
]).pick({
  age: undefined, category: 'worker'
})
