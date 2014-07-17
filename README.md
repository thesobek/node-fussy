# node-fussy

*JSON prediction and recommendation engine*

[![Build Status](https://secure.travis-ci.org/jbilcke/node-fussy.png)](http://travis-ci.org/jbilcke/node-fussy)
[![Dependency Status](https://gemnasium.com/jbilcke/node-fussy.png)](https://gemnasium.com/jbilcke/node-fussy)

## Summary

Fussy is a library for predicting missing values in a JSON object, using a
database of similar documents.

You can use it for various things, classification, marketing, prediction etc..  
For instance I am using it to solve some [basic machine learning problems](https://github.com/jbilcke/node-fussy-examples),
and it is pretty fun!

My goal is to make it scale on larger datasets (more than 20.000 items) but
there is still a long road.

## Notes / Todo

- Nested objects are UNSUPPORTED. Tell me if you really need this feature.
- Large datasets are slow to process. That's normal:
  The algorithm is `O(N*M)` (N: nb of objects to test, M: nb of objects in the database)
- See if we could speed things up by using other machine learning techniques,
  Or parallelize the job

## Quickstart / Tutorial

### Installation

First you need to install it in your project:

    $ npm install fussy --save

### Basic usage

Import the library, then create a compute stream on some input, and solve an incomplete JSON object:

```javascript
var Fussy = require('fussy');

Fussy('my/docs/*.json')
  .solve({
    foo: undefined, // this will be replaced by the best value
    bar: 'foobar'    // this will be used to find the best value
  })
```

### Creating and hacking a stream

`Fussy(..)` creates a computation stream, and provides a few functions which returns immediately:

  - `skip(Number)`: skips the N first objects in the stream

  - `limit(Number)`: limits to N objects

  - `debug(Boolean)`: shows or hide verbose debug log (in the standard output)

These functions configure and returns the stream, so you can chain them.

### Solving an object

No work will be done or data be read until you call one of the trigger functions. Trigger functions are the ones doing all the work to predict the undefined fields in your object:

  - `solve(Object, Function?)`: solves an object (returns a copy, original is untouched)

  - `repair(Object, Function?)`: solves an object (original will be updated in-place)

These functions take an optional callback function argument, for aysnchronous flow.

If you need quick debugging, or are writing a simple command-line script, you can use the synchronous mode for convenience.

## API Documentation

Now we can dive into the advanced features:

### Overview of supported input sources:

- `Fussy([{},{},..])`: Loads an array of Objects
- `Fussy('file.csv')`: Single CSV file
- `Fussy('*/*.json')`: Collection of local JSON files
- `Fussy('http://../foo.csv')`: Remote csv files
- `Fussy('mongo://../a/b')`: MongoDB collections

### Using a CSV source file

#### Basic CSV file

```javascript
var db = Fussy('test.csv');
```

#### Trimmed CSV file

 Load a CSV, skipping the first line, and keeping the 100 next lines:

```javascript
var db = Fussy('test.csv').skip(1).limit(100);
```

#### Alternative syntax

 You can also use an URL with the `file:` protocol:

```javascript
var db = Fussy('file://test.csv');
```

#### Alternative file path syntax

 You can also use an URL with the `file:` protocol:

```javascript
var db = Fussy('file://test.csv');
```

### Using a data schema

Default settings are enough in most cases. Fussy will try to:

  - use the first line to name columns, unless the header looks like data
  - figure out what kind of data you have (strings or numbers?)

However in some cases it won't work, and you will have to override the header.

or this, just skip the first line using `.skip(1)` and define a `Schema`:


```javascript
var db = Fussy('thermal.csv').skip(1).schema([
  'day',
  'temperature'
]);
```

Each item of the list correspond to a column in the CSV.

An item is a list of params :the first one is the column name, and the second one is the type (which is optional).

```javascript
var db = Fussy('thermal.csv').skip(1).schema([
    ['day','String'],
    ['temperature','Number']
]);
```

#### Type casting

Type must be Capitalized and one of these:

  - `'Number'`: continuous values (will use `1 / (1 + |a| - |b|)` for comparison)
  - `'Enum'`: discrete, enumeration-like values (will use boolean comparison)
  - `'String'`: discrete text values (will use a basic string distance comparison)
  - `'Boolean'`: boolean values (compared with boolean equality, discrete). Not quite supported at the moment.

For `Enum` type, you can also pass a key/value map, instead of writing "Enum".
Make sure you made no typos in the keys, or else weird things will happen.

```javascript
var db = Fussy('thermal.csv').skip(1).schema([
    ['day', {
      'mon': 'Monday',
      'tue': 'Tuesday',
      'wed': 'Wednesday',
      'thu': 'Thursday',
      'fri': 'Friday',
      'sat': 'Saturday',
      'sun': 'Sunday'
      }],
    ['temperature','Number']
]);
```

Finally, you can also use an external schema file:

```javascript
var db = Fussy('thermal.csv').skip(1).schema('schema.json');
```

### Using a remote file

```javascript
var remote = Fussy('http://foo.bar/data/set.csv');
```

Note: for the moment, there is no caching: it will re-connect and re-download content each time you call a trigger.

### Using a MongoDB collection

*Note: NOT TESTED, MIGHT BE BROKEN, WARNING WARNING*

```javascript
Fussy('mongo://myserver:27017/mydatabase/mycollection')
```

### The Query object

Queries are like view on your data: you create queries by calling the `query({ .. })`
function on a Fussy stream.

Creating a query returns a new one immediately, and most Query functions are
asyncronous, too, until you call one of the trigger functions:


## TODO

- run multiples queries at once (because streaming / iterating over a collection is more costly than iterating over queries, which stay in memory)
- implement caching? something like: `fussy.cache(length: 1000, timeout: 3600)`
- parallelize using forks?
- find a clean way to run it with Hadoop / MapReduce?
