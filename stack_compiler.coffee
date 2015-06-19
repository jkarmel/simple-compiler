assert = require 'assert'
_ = require 'lodash'

ops =
  push: (m, val) ->
    m.stack.push val
  add: (m) ->
    a = m.stack.pop()
    b = m.stack.pop()
    m.stack.push a + b
  subtract: (m) ->
    diff = m.stack.pop()
    from = m.stack.pop()
    m.stack.push(from - diff)
  trashVar: (m) ->
    m.vars.pop()
  pushVar: (m, index) ->
    m.stack.push m.vars[index]
  popToVars: (m) ->
    m.vars.push m.stack.pop()

run = (instructions) ->
  machine =
    stack: []
    vars: []
  for instruction in instructions
    [op, args...] = instruction
    ops[op].apply {}, [machine, args...]
  machine.stack[0]

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

emit =
  instructions: (x, env = []) ->
    return [['push', x]] if _.isNumber x
    return [['pushVar', env.indexOf(x)]] if _.includes env, x
    op = x[0]
    if PRIMITIVE_OPS[op]
      emit.primitive x, env
    else if op == 'let'
      emit.let x, env

  let: (x, outer) ->
    [op, binding, body] = x
    [name, expression] = binding
    inner = _(_.clone(outer)).push(name).value()
    _.flatten [
      emit.instructions expression, outer
      [['popToVars']]
      emit.instructions body, inner
      [['trashVar']]
    ]

  primitive: (x, env) ->
    [op, args...] = x
    # ensure top of stack contains the evaluated arguements for
    # the primitive operation
    instructions = _.flatten _.map args, (arg) -> emit.instructions arg, env
    instructions.concat [[PRIMITIVE_OPS[op]]]

assert.deepEqual [
  ['push', 7]
  ['push', 3]
  ['subtract']
  ['push', 1]
  ['push', 2]
  ['add']
  ['add']
], emit.instructions ['+', ['-', 7, 3], ['+', 1, 2 ]]

compile = (string) -> emit.instructions parse string

assert 7 == run compile "[+ [- 7 3] [+ 1 2]]"
assert 4 == run compile "[let [x 7] [let [y 3] [- x y]]]"
