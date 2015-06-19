assert = require 'assert'
_ = require 'lodash'

ops =
  push: (stack, val) ->
    stack.push val
  add: (stack) ->
    a = stack.pop()
    b = stack.pop()
    stack.push a + b
  subtract: (stack) ->
    diff = stack.pop()
    from = stack.pop()
    stack.push(from - diff)

run = (instructions) ->
  stack = []
  for instruction in instructions
    [op, args...] = instruction
    ops[op].apply {}, [stack, args...]
  stack[0]

add4And3 = [
  ['push', 4]
  ['push', 3]
  ['add']
]

assert 7 == run add4And3

subtract3From7 = [
  ['push', 7]
  ['push', 3]
  ['subtract']
]

assert 4 == run subtract3From7

parse = (string) ->
  JSON.parse(string.replace(/\s/g,",").replace(/[a-z\+\-]+/g, '"$&"'))

assert.deepEqual ['+', ['-', 7, 3], ['+', 1, 2 ]], parse "[+ [- 7 3] [+ 1 2]]"

PRIMITIVE_OPS =
  '+': 'add'
  '-': 'subtract'

generateInstructions = (program) ->
  return [['push', program]] if _.isNumber program
  [op, args...] = program
  instructions = _.flatten _.map args, generateInstructions
  instructions.concat [[PRIMITIVE_OPS[op]]]

assert.deepEqual [
  ['push', 7],
  ['push', 3],
  ['subtract'],
  ['push', 1],
  ['push', 2],
  ['add'],
  ['add']
], generateInstructions ['+', ['-', 7, 3], ['+', 1, 2 ]]

compile = (string) -> generateInstructions parse string

assert 7 == run compile "[+ [- 7 3] [+ 1 2]]"
