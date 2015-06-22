assert = require 'assert'
_ = require 'lodash'
require 'shelljs/global'
fs = require 'fs'

parse = (string) ->
  JSON.parse(string.replace(/\s/g,",").replace(/[a-z\+\-]+/g, '"$&"'))

assert.deepEqual ['+', ['-', 7, 3], ['+', 1, 2 ]], parse "[+ [- 7 3] [+ 1 2]]"

square10 = [['define', 'square', ['x'], ['*', 'x', 'x']],
            ['square', 10]]

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
    console.log env: env, body: body
    return "push $#{body}" if _.isNumber body
    return "push -#{4 * (_.indexOf(env, body) + 1)}(esb)" if _.include env, body
    [fn, args...] = body
    asm = for arg in args
      generate.body arg, definitions, env
    final = if definitions[fn]
      "call #{fn}"
    else if fn is '*'
      """
      pop %r8
      pop %r9
      add %r8, %r9
      push %r9
      """
    asm.concat([final]).join "\n"

console.log JSON.stringify generate.assembly extractProcedureDefinitions square10

assembly = """
       .section        __TEXT,__text,regular,pure_instructions
       .macosx_version_min 10, 10
       .align  4, 0x90
       .globl  _main

_multiply:
mov 8(%rsp), %r8
mov 16(%rsp), %r9
imul %r8, %r9
mov %r9, %rax
ret

_square:
push   %rbp
mov    %rsp, %rbp
mov 16(%rbp), %rax
imul 16(%rbp), %rax
leave
ret


_main:                                  ## @main

push   %rbp
mov    %rsp, %rbp
sub    $16, %rsp
lea    .str(%rip), %rdi

# my program
# get the right value into eax

push $12
call _square
add $8, %rsp

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
