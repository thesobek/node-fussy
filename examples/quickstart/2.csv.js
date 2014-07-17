var Fussy = require('fussy');

function echo(x) { console.log(Fussy.pretty(x)); };

// csv loaded like this will have (more or less) dynamic schemas
echo(
  Fussy('people.csv')
  .solve({
    age: 18,
    category: undefined
  })
);

// will print: { age: 18, category: 'student' }


// You can also pass a schema to map columns to json attributes, useful if you have
// no header, or want better control over types


echo(
  Fussy('people.csv')
  .schema([
    ['age', 'Number'],
    ['category','String']
  ]).solve({
    age: 18,
    category: undefined
  })
);
