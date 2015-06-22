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
    for name, {args, body} definitions of program.definitions
      assembly[name] = generate.body body, args
    assembly
    main: generate.body program.main
    definitions: assemblyDefinitions
  body: (body, definitions, env = []) ->
    [fn, args...] = body
    if definitions[fn]

console.log JSON.stringify extractProcedureDefinitions square10

assembly = """
       .section        __TEXT,__text,regular,pure_instructions
       .macosx_version_min 10, 10
       .align  4, 0x90
       .globl  _main
_main:                                  ## @main
push   %rbp
mov    %rsp, %rbp
sub    $16, %rsp
lea    .str(%rip), %rdi

# my program
# get the right value into eax

mov $10, %eax
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
