assert = require 'assert'
_ = require 'lodash'
require 'shelljs/global'
fs = require 'fs'

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

string = "[+ [- 7 3] [+ 1 4]]"
assert 7 == run compile "[+ [- 7 3] [+ 1 2]]"

assembly =
  from: (instructions) ->
    asm = for instruction in instructions
      switch instruction[0]
        when 'push'
          "push $#{instruction[1]}"
        when 'add'
          """
          pop %r8
          pop %r9
          add %r8, %r9
          push %r9
          """
        when 'subtract'
          """
          pop %r8
          pop %r9
          sub %r8, %r9
          push %r9
          """
    asm.join('\n')

code = assembly.from compile string

assembly = """
	.section	__TEXT,__text,regular,pure_instructions
	.macosx_version_min 10, 10
	.align	4, 0x90
	.globl	_main
_main:                                  ## @main
push	%rbp
mov	%rsp, %rbp
sub	$16, %rsp
lea	.str(%rip), %rdi

# my program
# get the right value into eax
#{code}
pop %rax

## The value in %esi will be printed
mov %eax, %esi

mov $0, %al
call _printf
add $16, %rsp
pop %rbp
ret

	.section	__TEXT,__cstring,cstring_literals
.str:                                 ## @.str
	.asciz	"%d\n"


.subsections_via_symbols
"""
fs.writeFileSync('tmp.s', assembly)
exec 'gcc -c tmp.s -o tmp.o && gcc tmp.o -o tmp && ./tmp'
