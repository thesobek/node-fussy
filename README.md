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
there still a long road.

## Notes / Todo

- Nested objects are UNSUPPORTED. Tell me if you really need this feature.
- Larges datasets are slow to process. That's normal:
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

  - `debug(true|false)`: shows or hide verbose debug log (in the standard output)

These functions configure and returns the stream, so you can chain them.

### Solving an object

No work will be done or data be read until you call one of the trigger functions. Trigger functions are the ones doing all the work to predict the undefined fields in your object:

  - `solve(Object, Function?)`: solves an object (returns a copy, original is untouched)

  - `repair(Object, Function?)`: solves an object (original will be updated in-place)

These functions take an optional callback function argument, for aysnchronous flow.

If you need quick debugging, or are writing a simple command-line script, you can use the synchronous mode for convenience.

## API Documentation

Now we can dive into the advanced features:

### Using a CSV source file

#### Basic CSV file

```javascript
Fussy('test.csv')
```

#### Trimmed CSV file

 Load a CSV, skipping the first line, and keeping the 100 next lines:

```javascript
Fussy('test.csv')
  .skip(1)
  .limit(100)
```
#### Alternative syntax

 You can also use an URL with the `file:` protocol:

```javascript
Fussy('file://test.csv')
```

#### Typecasting CSV columns

By default, Fussy will scratch its head and try to figure out what kind of data it deals with.


### Using a remote file

*Note: for the moment this is available for asynchronous trigger calls only.*

```javascript
Fussy('http://foo.bar/data/set.csv')
```
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
