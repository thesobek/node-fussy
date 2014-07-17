
// First you need to load the library
var Fussy = require('fussy');

// pretty() is just some helper function to dump an object as a string
console.log(Fussy.pretty({ foo: 'bar' }));

// the basic usage for Fussy is to use it on a collection of JSONs
var data = [
  { foo: 'bar' },
  { bar: 'foo' }
];

// just call the input function on it
var db = Fussy(data);
