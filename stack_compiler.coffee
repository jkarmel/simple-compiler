assert = require 'assert'
_ = require 'lodash'
require 'shelljs/global'
fs = require 'fs'

parse = (string) ->
  JSON.parse(string.replace(/\s/g,",").replace(/[a-z\+\-]+/g, '"$&"'))

assert.deepEqual ['+', ['-', 7, 3], ['+', 1, 2 ]], parse "[+ [- 7 3] [+ 1 2]]"

cube10 = [['define', 'cube', ['x'], ['*', ['*', 'x', 'x'], 'x']],
            ['cube', 10]]

extractProcedureDefinitions = (ast) ->
  definitions = _.select ast, (node) -> node[0] is 'define'
  definitions = _.object _.map definitions, (def) ->
    [def[1], {args: def[2], body: def[3]}]
  {definitions: definitions, main: _.last(ast)}

generate =
  assembly: (program) ->
    assembly = {}
    for name, {args, body} of program.definitions
      assembly[name] = generate.body body, program.definitions, args
    assembly
    main: generate.body program.main, program.definitions
    definitions: assembly
  body: (body, definitions, env = []) ->
    return "push $#{body}" if _.isNumber body
    return "push #{8 * (_.indexOf(env, body) + 2)}(%rbp)" if _.include env, body
    [fn, args...] = body
    asm = for arg in args
      generate.body arg, definitions, env
    final = if definitions[fn]
      """
      call _#{fn}
      add $#{8 * args.length}, %rsp
      push %rax
      """
    else if fn is '*'
      """
      call _multiply
      add $#{8 * args.length}, %rsp
      push %rax
      """
    asm.concat([final]).join "\n"

assembly = generate.assembly extractProcedureDefinitions cube10

definitions = for name, definition of assembly.definitions
  """
  _#{name}:
  push   %rbp
  mov    %rsp, %rbp

  #{definition}
  pop %rax

  leave
  ret
  """

definitions.join("\n")

assembly = """
       .section        __TEXT,__text,regular,pure_instructions
       .macosx_version_min 10, 10
       .align  4, 0x90
       .globl  _main

_multiply:
push   %rbp
mov    %rsp, %rbp
mov 16(%rbp), %rax
imul 24(%rbp), %rax
leave
ret


#{definitions}

_main:                                  ## @main

push   %rbp
mov    %rsp, %rbp
sub    $16, %rsp
lea    .str(%rip), %rdi

# my program
# get the right value into eax

#{assembly.main}
pop %rax

## The value in %esi will be printed
mov %eax, %esi

mov $0, %al
call _printf
add $16, %rsp
pop %rbp
ret

       .section        __TEXT,__cstring,cstring_literals
.str:                                 ## @.str
       .asciz  "%d\n"
.subsections_via_symbols
"""

fs.writeFileSync('tmp.s', assembly)
exec 'gcc -c tmp.s -o tmp.o && gcc tmp.o -o tmp && ./tmp'
