assert = require 'assert'
_ = require 'lodash'
require 'shelljs/global'
fs = require 'fs'

replace = (string) -> string.replace(/\s+/g,",").replace(/[a-z\+\-\*\_]+/g, '"$&"')
parse = (string) -> JSON.parse replace string

assert.deepEqual ['+', ['-', 7, 3], ['+', 1, 2 ]], parse "[+ [- 7 3] [+ 1 2]]"

extractProcedureDefinitions = (ast) ->
  definitions = _.select ast, (node) -> node[0] is 'define'
  definitions = _.object _.map definitions, (def) ->
    [def[1], {args: def[2], body: def[3]}]
  {definitions: definitions, main: _.last(ast)}

PRIMITIVE =
  '+': 'add'
  '*': 'multiply'

generate =
  assembly: (program) ->
    assembly = {}
    for name, {args, body} of program.definitions
      assembly[name] = generate.body body, program.definitions, args
    assembly
    main: generate.body program.main, program.definitions
    definitions: assembly
  body: (body, definitions, env = []) ->
    if _.isNumber body
      "push $#{body}"
    else if _.include env, body
      # we add one is added above the arguments
      # we subtrack from the number of arguments
      # because arguments were pushed onto the stack
      # in order of appearance so the first argument
      # is further down the stack. We multiply by
      # 8 because each item on the stack is 64 bits (8 bytes)
      stackOffest = (1 + env.length - _.indexOf(env, body)) * 8
      return "push #{stackOffest}(%rbp)"
    else
      [fn, args...] = body
      asm = for arg in args
        generate.body arg, definitions, env
      name = if definitions[fn] then fn else PRIMITIVE[fn]
      final = """
        # call the procedure
        call _#{name}
        # move the stack pointer past the arguments we pushed for the function call
        add $#{8 * args.length}, %rsp
        # the result is in %rax but we want to add it to the stack for
        # whatever procedure is coming next
        push %rax
        """
      asm.concat([final]).join "\n"


compile = (string) ->
  assembly = generate.assembly extractProcedureDefinitions parse string

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

  """
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

  _add:
  push   %rbp
  mov    %rsp, %rbp
  mov 16(%rbp), %rax
  add 24(%rbp), %rax
  leave
  ret

  # for some reason if I push anything
  # onto the stack I get a seg fault
  # so when _print_int is called
  # the value of %rax must contain the int
  # (ie we aren't using normal calling conventions)
  _print_int:
  push   %rbp
  mov    %rsp, %rbp

  ## The value in %esi will be printed
  mov %rax, %rsi
  mov $0, %al
  lea    .str(%rip), %rdi
  push %rsi
  push %rdi
  call _printf
  add $16, %rsp

  leave
  ret



  #{definitions.join("\n")}

  _main:                                  ## @main

  push   %rbp
  mov    %rsp, %rbp

  # my program
  # get the right value into eax

  #{assembly.main}
  pop %rax

  call _print_int

  leave
  ret

        .section        __TEXT,__cstring,cstring_literals
  .str:                                 ## @.str
        .asciz  "%d\n"
  .subsections_via_symbols
  """


run = (string) ->
  assembly = compile string
  fs.writeFileSync('tmp.s', assembly)
  exec 'gcc -c tmp.s -o tmp.o && gcc tmp.o -o tmp && ./tmp > res'
  result = fs.readFileSync('res').toString()[0..-2] # chop of trailing \n
  exec 'rm tmp.s tmp.o tmp res'
  result

assert.equal "3", run """
[[+ 1 2]]
"""

assert.equal "3", run """
[[define add_one [x] [+ 1 x]]
  [add_one 2]]
"""

assert.equal "23", run """
[[define multiply_then_add [a b c] [+ [* a b] c]]
  [multiply_then_add 5 4 3]]
"""

assert.equal "100", run """
[[define square [x] [* x x]]
  [square 10]]
"""

assert.equal "1000", run """
[[define cube [x] [* [* x x] x]]
  [cube 10]]
"""

assert.equal "1000", run """
[[define square [x] [* x x]]
 [define cube [x] [* [square x] x]]
 [cube 10]]
"""

assert.equal "13", run """
[[define square [x] [* x x]]
 [define sum_of_squares [x y] [+ [square x] [square y]]]
 [sum_of_squares 2 3]]
"""
