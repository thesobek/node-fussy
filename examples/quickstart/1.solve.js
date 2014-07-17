var Fussy = require('fussy');

function echo(x) { console.log(Fussy.pretty(x)); };

echo(Fussy([
  { age: 5,  category: 'children' },
  { age: 15, category: 'pupil'    },
  { age: 17, category: 'student'  },
  { age: 18, category: 'student'  },
  { age: 18, category: 'worker'   },
  { age: 20, category: 'student'  },
  { age: 23, category: 'worker'   },
  { age: 25, category: 'worker'   },
  { age: 30, category: 'worker'   }
]).solve({age: 18, category: undefined}));

// will print: { age: 18, category: 'student' }
