"use strict"

chai = require 'chai'
should = chai.should()
expect = chai.expect
chai.use require 'chai-interface'
chai.use require 'chai-stats'

Fussy = require 'fussy'

dogs = Fussy [
  { name: 'Doge',    breed: 'Shiba Inu',       size: 13 }
  { name: 'Kaito',   breed: 'Shiba Inu',       size: 15 }
  { name: 'Jun',     breed: 'Shiba Inu',       size: 17 }
  { name: 'Sora',    breed: 'Akita',           size: 26 }
  { name: 'Tatsuya', breed: 'Akita',           size: 24 }
  { name: 'Isao',    breed: 'Akita',           size: 28 }
  { name: 'Max',     breed: 'English Pointer', size: 23 }
  { name: 'Pluto',   breed: 'English Pointer', size: 28 }
  { name: 'Buddy',   breed: 'Husky',           size: 24 }
  { name: 'Buster',  breed: 'Husky',           size: 22 }
  { name: 'Alagan',  breed: 'Combai',          size: 25 }
  { name: 'Chetan',  breed: 'Combai',          size: 17 }
]

class Dog

  constructor: (opts={})->

    @name  = opts.name
    @breed = opts.breed
    @size  = opts.size

  bark: -> "woof"

sync_dog = new Dog
  breed: 'English Pointer'

dogs.repair sync_dog

expect(sync_dog).to.be.an.instanceof(Dog)

sync_dog.should.have.interface
  name: String
  breed: String
  size: String # that's an error, it should be: Number
  bark: Function

sync_dog.size.should.be.within(23, 28)

console.log Fussy.pretty sync_dog

async_dog = new Dog
  breed: 'English Pointer'

dogs.repair async_dog, ->

  expect(async_dog).to.be.an.instanceof(Dog)

  async_dog.should.have.interface
    name: String
    breed: String
    size: String # that's an error, it should be: Number
    bark: Function

  async_dog.size.should.be.within(23, 28)
