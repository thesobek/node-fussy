"use strict"

fs = require 'fs'

intercept = require 'intercept-stdout'
chai = require 'chai'
should = chai.should()
expect = chai.expect

###
First you need to load the library
###
Fussy = require 'fussy'


# the basic usage for Fussy is to use it on a collection of JSONs

describe 'basic usage of fussy', ->

  it 'should throw an exception when called without params', ->
    db = Fussy [
      { foo: 'bar' }
      { bar: 'foo' }
    ]

    expect(db.solve).to.throw(/cannot be called without param/);
    expect(db.repair).to.throw(/cannot be called without param/);
    expect(db.query).to.throw(/cannot be called without param/);

  it 'should log debug messages to the console', ->

    # this capture the output of Fussy.debug and compare it with some
    # pre-recorded output, to comapre
    fs.readFile './tests/data/test-debug.txt', 'utf8', (err, data) ->

      out = ""

      stopIntercept = intercept (txt) -> out += txt

      Fussy.debug(yes)
      Fussy([
        { foo: 'bar' }
        { bar: 'foo' }
      ]).solve({})
      Fussy.debug(no)

      stopIntercept()

      # remove ANSI colors
      out.replace(/\033\[[0-9;]*m/g,'').should.equal data
