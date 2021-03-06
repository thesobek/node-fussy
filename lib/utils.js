// Generated by CoffeeScript 1.7.1

/*
WARNING:
This file is quite old, and could use some cleaning or refactoring.

Maybe be split into submodules, and cleaner way of handling synchronous and
asynchronous modes.
 */


/*
standard library
 */

(function() {
  var colors, csvString, dataset, deck, fields2map, find, findsum, fs, isArray, isBoolean, isEmpty, isFunction, isNumber, isString, loadCSV, loadJSON, loadSchema, parse, parseMany, parseOne, parse_cache, path, pperf, pretty, pstats, randomizeCSV, util,
    __hasProp = {}.hasOwnProperty,
    __slice = [].slice;

  util = require('util');

  fs = require('fs');

  path = require('path');


  /*
  managed modules
   */

  deck = require('deck');

  colors = require('colors');

  csvString = require('csv-string');


  /*
  Check if a reference is an Array. We use the native function.
   */

  exports.isArray = isArray = util.isArray;


  /*
  Check if a reference is a String.
  
  (taken from underscore.coffee)
   */

  exports.isString = isString = function(obj) {
    return !!(obj === '' || (obj && obj.charCodeAt && obj.substr));
  };


  /*
  Check if a reference is a Function.
  
  (taken from underscore.coffee)
   */

  exports.isFunction = isFunction = function(obj) {
    return !!(obj && obj.constructor && obj.call && obj.apply);
  };


  /*
  Check if a reference is a Boolean.
  
  (taken from underscore.coffee)
   */

  exports.isBoolean = isBoolean = function(obj) {
    return obj === true || obj === false;
  };


  /*
  Check if a reference is a Number.
  
  (taken from underscore.coffee)
   */

  exports.isNumber = isNumber = function(obj) {
    return toString.call(obj) === '[object Number]';
  };


  /*
  Check is an object is empty.
  
  (taken from underscore.coffee)
   */

  exports.isEmpty = isEmpty = function(obj) {
    var key;
    if (isArray(obj) || isString(obj)) {
      return obj.length === 0;
    }
    for (key in obj) {
      if (!__hasProp.call(obj, key)) continue;
      return false;
    }
    return true;
  };


  /*
  Pretty-print an object (convert to coloured string)
   */

  exports.pretty = pretty = function(obj) {
    return "" + (util.inspect(obj, false, 20, true));
  };


  /*
  Pretty-print performances.
  
  This is a low-level function, just pretty printing the value to colored string.
   */

  exports.pperf = pperf = function(nbErrors, total, decimals) {
    var p, t;
    if (total == null) {
      total = 100;
    }
    if (decimals == null) {
      decimals = 2;
    }
    p = 100 - (nbErrors / total) * 100;
    t = "" + (p.toFixed(decimals)) + "%";
    if (p < 50) {
      return t.red;
    } else if (p < 80) {
      return t.yellow;
    } else {
      return t.green;
    }
  };


  /*
  Pretty-print performances.
  
  This is a high-level function, printing out some more info, in addition to the
  actual performance.
   */

  exports.pstats = pstats = function(_arg) {
    var errors, tests;
    errors = _arg.errors, tests = _arg.tests;
    return "performance: " + pperf(errors, tests) + (" (" + errors + " errors for " + tests + " tests)");
  };


  /*
  TODO Document and add comments to this function
   */

  exports.fields2map = fields2map = function(fields) {
    var field, k, key, map, v, values, _i, _len;
    map = {};
    if (fields.length === 1) {
      field = fields[0];
      if (isString(field)) {
        map[field] = [];
      } else if (isArray(field)) {
        for (k in field) {
          v = field[k];
          map[k] = v;
        }
      } else {
        for (key in field) {
          values = field[key];
          map[key] = isArray(values) ? values : [values];
        }
      }
    } else {
      for (_i = 0, _len = fields.length; _i < _len; _i++) {
        field = fields[_i];
        map[field] = [];
      }
    }
    return map;
  };


  /*
  TODO Document and add comments to this function
   */

  exports.findsum = findsum = function(obj, pattern, root) {
    var head, key, last, match, sub_sum, tmp, value, x, _ref, _ref1;
    if (root == null) {
      root = true;
    }
    _ref = pattern.split('.'), head = _ref[0], last = 2 <= _ref.length ? __slice.call(_ref, 1) : [];
    tmp = 0;
    match = false;
    for (key in obj) {
      value = obj[key];
      if (head === '*' || head === key) {
        match = true;
        if (last.length === 0) {
          x = Number(value);
          if (!isNaN(x)) {
            tmp += x;
          }
        } else {
          _ref1 = findsum(value, last.join('.'), false), sub_sum = _ref1[0], match = _ref1[1];
          if (match === true) {
            tmp += sub_sum;
          }
        }
      }
    }
    if (root) {
      return tmp;
    } else {
      return [tmp, match];
    }
  };


  /*
  TODO Document and add comments to this function
   */

  exports.find = find = function(obj, pattern, root) {
    var head, k, key, last, match, sub_map, tmp, v, value, x, _ref, _ref1, _ref2, _ref3;
    if (root == null) {
      root = true;
    }
    _ref = pattern.split('.'), head = _ref[0], last = 2 <= _ref.length ? __slice.call(_ref, 1) : [];
    tmp = {};
    match = false;
    for (key in obj) {
      value = obj[key];
      if (head === '*' || head === key) {
        match = true;
        if (last.length === 0) {
          x = Number(value);
          if (!isNaN(x)) {
            tmp[key] = (_ref1 = x + tmp[key]) != null ? _ref1 : 0;
          }
        } else {
          _ref2 = findsum(value, last.join('.'), false), sub_map = _ref2[0], match = _ref2[1];
          if (match === true) {
            for (k in sub_map) {
              v = sub_map[k];
              tmp[k] = (_ref3 = v + tmp[k]) != null ? _ref3 : 0;
            }
          }
        }
      }
    }
    if (root) {
      return tmp;
    } else {
      return [tmp, match];
    }
  };


  /*
  A global cache, used to store schema.
  
  TODO FIXME
  Doing this is prone to memory leaks. Schemas are lightweight, but never deleted.
  A better implementation would use an expiration timeout, or limits the number of
  stored schemas.
   */

  parse_cache = {};


  /*
  Load a dataset schema.
  
  Can be:
   - a String (file path to JSON file)
   - a JSON object (pre-loaded file).
   */

  exports.loadSchema = loadSchema = function(schema) {
    if (isString(schema)) {
      if (schema in parse_cache) {
        return parse_cache[schema];
      } else {
        return parse_cache[schema] = JSON.parse("" + (fs.readFileSync(schema)));
      }
    } else {
      return schema;
    }
  };


  /*
  private function, used to parse a CSV row
  TODO FIXME rename to something like parseCSVRow?
   */

  parse = function(schema, row) {
    var columns, facts, i, key, values, _i, _ref, _ref1;
    columns = [];
    columns = csvString.parse(row)[0];
    if (columns.length > schema.length) {
      throw "invalid columns length (" + columns.length + "), does not match schema (" + schema.length + ")";
    }
    facts = {};
    for (i = _i = 0, _ref = columns.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      if (isString(schema[i])) {
        facts[schema[i]] = columns[i];
        continue;
      }
      if (schema[i].length === 1) {
        facts[schema[i][0]] = columns[i];
        continue;
      }
      _ref1 = schema[i], key = _ref1[0], values = _ref1[1];
      if (!values) {
        facts[key] = columns[i];
        continue;
      }
      if (isString(values)) {
        if (values === "Number") {
          facts[key] = Number(columns[i]);
        } else if (values === "Boolean") {
          facts[key] = Boolean(columns[i]);
        } else if (values === "String") {
          facts[key] = "" + columns[i];
        } else if (values === "Symbol") {
          facts[key] = "" + columns[i];
        } else {
          throw "unrecognized type '" + values + "'";
        }
      } else {
        if (columns[i] in values) {
          facts[key] = values[columns[i]];
        } else {
          facts[key] = columns[i];
        }
      }
    }
    return facts;
  };

  exports.parseOne = parseOne = function(schema, row) {
    schema = loadSchema(schema);
    return parse(schema, row);
  };

  exports.parseMany = parseMany = function(schema, rows) {
    var row, _i, _len, _results;
    schema = loadSchema(schema);
    _results = [];
    for (_i = 0, _len = rows.length; _i < _len; _i++) {
      row = rows[_i];
      _results.push(parse(schema, row));
    }
    return _results;
  };


  /*
  Loads a JSON file
  
  TODO FIXME This function is a bit of a callback hell!
   */

  exports.loadJSON = loadJSON = function(filePath, cb) {
    var execDir, execPath, scriptDir, scriptPath, _load;
    execDir = process.cwd();
    execPath = execDir + '/' + filePath;
    scriptPath = void 0;
    if (process.argv.length > 1) {
      scriptDir = process.argv[1].split('/').slice(0, -1).join('/');
      scriptPath = scriptDir + '/' + filePath;
    }
    _load = function(file) {
      if (cb != null) {
        return JSON.parse(fs.readFile(file, 'UTF-8', function(err, data) {
          if (err) {
            throw err;
          }
          return cb(JSON.parse(data));
        }));
      } else {
        return JSON.parse(fs.readFileSync(file, 'UTF-8'));
      }
    };
    if (cb != null) {
      return fs.exists(filePath, function(exists) {
        if (exists) {
          return _load(filePath);
        }
        return fs.exist(execPath, function(exists) {
          if (exists) {
            return _load(execPath);
            if (!scriptPath) {
              throw "couldn't find file";
            }
            return fs.exists(scriptPath, function(exists) {
              if (exists) {
                return _load(scriptPath);
              } else {
                throw "couldn't find file";
              }
            });
          }
        });
      });
    } else {
      if (fs.existsSync(filePath)) {
        return _load(filePath);
      }
      if (fs.existsSync(execPath)) {
        return _load(execPath);
      }
      if (!scriptPath) {
        throw "couldn't find file";
      }
      if (fs.existsSync(scriptPath)) {
        return _load(scriptPath);
      }
      return {};
    }
  };


  /*
  Load a CSV file, from a filepath
  
  This function assumes rows have '\n' line returns
   */

  exports.loadCSV = loadCSV = function(filePath) {
    var dataset, row, _i, _len, _ref;
    dataset = [];
    _ref = fs.readFileSync(filePath).toString().split("\n");
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      row = _ref[_i];
      if (row.length) {
        dataset.push(row);
      }
    }
    return dataset;
  };


  /*
  Shuffle an Array
   */

  exports.shuffle = deck.shuffle;


  /*
  TODO FIXME OBSOLETE
   */

  exports.randomizeCSV = randomizeCSV = function(filePath) {
    var dataset;
    dataset = loadCSV(filePath);
    return deck.shuffle(dataset);
  };


  /*
  High-level function, to load a dataset (eg. CSV) using a schema,
  with optional "from" and "to" indexes, used like this: array[from...to]
   */

  exports.dataset = dataset = function(uri, schema, from, to) {
    var data, splice;
    data = loadCSV(uri);
    splice = from && to ? data.slice(from, to) : from ? data.slice(from) : to ? data.slice(0, to) : data;
    return parseMany(schema, splice);
  };

}).call(this);
