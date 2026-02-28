---
name: c-best-practices
description: C coding style and conventions for consistency—naming, formatting, headers, and structure. Use when writing or reviewing C code, adding to C codebases, or when the user asks for C style or best practices.
---

# C Best Practices

Style and structural conventions derived from a consistent C codebase (fype). Apply when writing or reviewing C.

## When to Use

- Writing new C source or headers
- Reviewing or refactoring C code
- Aligning code with a strict, readable C style
- Resolving style questions (naming, braces, pointers, line length)

## Naming Conventions

| Category | Convention | Examples |
|----------|------------|----------|
| Types (structs, enums, typedefs) | PascalCase | `Token`, `TokenType`, `List`, `Scope` |
| Functions | module_action (snake_case) | `token_new`, `list_add_back`, `scope_get` |
| Variables | prefix_name (type prefix) | `p_token`, `i_val`, `c_val`, `u_id`, `b_flag` |
| Macros/constants | UPPER_SNAKE_CASE | `TT_INTEGER`, `DEBUG_GC`, `NO_DEFAULT` |
| Enum values | MODULE_PREFIX_NAME | `TT_STRING`, `SYM_VARIABLE` |
| Callbacks | name_cb | `token_delete_cb`, `list_delete_cb` |
| Static/private functions | _prefix_name | `_scope_get_hash`, `_list_copy_cb` |

Variable prefixes: `p_` pointer, `i_` int, `c_` char/string, `u_` unsigned, `b_` bool. Use consistently.

## Formatting

- **Indentation**: 3 spaces, no tabs.
- **Line length**: Max 80 characters.
- **Braces**: K&R—opening brace on same line as statement/condition.
- **Pointer asterisk**: Attach to variable, not type—`Token *p_token`, not `Token* p_token`.
- **Return statements**: Parenthesize—`return (p_token);`

## Function Definitions

Put return type on its own line:

```c
Token*
token_new(char *c_val, TokenType tt_cur, int i_line_nr,
         int i_pos_nr, char *c_filename) {
   Token *p_token = token_new_dummy();
   // ...
   return (p_token);
}
```

Long parameter lists: align continuation lines with the first parameter or use a single indent.

## Header Guards

Use the traditional pattern; guard name = uppercase filename with `.` → `_`:

```c
#ifndef TOKEN_H
#define TOKEN_H
// ...
#endif
```

## File Headers

Source files start with a license/attribution block. Use a distinct block comment format (e.g. `/*:*` … `*:*/`) so it can be recognized by tooling. Include at least: file path, short description, copyright, and license summary.

## Comments

- Block comments: `/* ... */`
- Single-line: `// comment`
- Avoid trailing inline comments for non-trivial explanations; put notes on their own line(s) above or below.

## Struct Formatting

- **One member per line**; indent members with 3 spaces inside the brace block.
- **Self-referential structs**: give the struct a tag with trailing underscore, typedef to PascalCase:
  ```c
  typedef struct ListElem_ {
     struct ListElem_ *p_next;
     struct ListElem_ *p_prev;
     void *p_val;
  } ListElem;
  ```
- **Non–self-referential structs**: use anonymous struct: `typedef struct { ... } TypeName;`
- **Order in header**: define element/helper structs first, then the main container/type, then iterator or state structs. Use the same type-prefix for member names (`p_`, `i_`, etc.).
- **Internal-only structs** (used only in .c): define them in the .c file, not in the header; name with leading underscore or module prefix (e.g. `_Garbage`, `OpEntry`).

## One Module per File

- **One logical “class” (module) per file pair**: `foo.h` + `foo.c` for the main type and everything that belongs to it.
- **File named after the main type**: `list.h`/`list.c` for List, `token.h`/`token.c` for Token.
- **Related types in the same file**: the main type, its element/node type (e.g. `ListElem`), and any iterator or state type (e.g. `ListIterator`, `ListIteratorState`) live in the same header and implementation. Do not split each type into its own file.
- **Enums** that are part of the module (e.g. `TokenType`, `HASH_OP`) stay in that module’s header.

## new_ / delete Pattern

- **Constructor**: provide `Type *type_new(...)` that allocates and initializes. Variants as needed: `type_new()`, `type_new_size(int)`, `type_new_copy(Type *)`, `type_new_dummy()`.
- **Destructor**: provide `void type_delete(Type *p_type)` (or `type_clear` when only clearing contents). Always pair every `_new` with a corresponding `_delete`.
- **Sub-types in the same module** get their own new/delete with a consistent prefix:
  - Element/node: `ListElem *listelem_new()`, `void stackelem_...` (if exposed).
  - Iterator: `ListIterator *listiterator_new(List *p_list)`, `void listiterator_delete(ListIterator *p_iter)`.
- **Callback-style destructor**: when the type is passed as `void*` to a generic callback (e.g. list iterate-and-free), provide `void type_delete_cb(void *p_void)` that casts and calls `type_delete`.

## Iterator Pattern

- **Create/destroy**: `TypeIterator *typeiterator_new(Container *p_container)`, `void typeiterator_delete(TypeIterator *p_iter)`.
- **Traversal**: `void *typeiterator_next(TypeIterator *p_iter)`, `_Bool typeiterator_has_next(TypeIterator *p_iter)`. Add `typeiterator_current`, `typeiterator_prev`, etc. as needed.
- Iterator type and its functions live in the same module as the container (same .h/.c).

## Callbacks (_cb)

- Any function that is used as a callback and takes `void*` (or `void*, void*`, etc.) should be suffixed with `_cb`: e.g. `list_delete_cb`, `token_print_cb`, `reference_delete_cb`. This marks the signature as callback-compatible.

## Header Layout Order

1. Header guard
2. `#include` (system then project/local)
3. Macros and accessor macros for the type
4. Enums (if any)
5. Struct typedefs (element/helper, then main type, then iterator/state)
6. Function declarations: `_new` / `_delete` first, then the rest (grouped logically)

Optional: close with `#endif /* GUARD_H */` for clarity.

## Accessors and Macros

- **Naming**: `module_get_field(obj)`, `module_set_field(obj, val)` (e.g. `token_get_val`, `symbol_set_val`). Use macros in the header for trivial access; use functions for non-trivial logic.
- Simple accessors: `list_first(l)`, `hash_get_cur_size(hash)`. Keep macros side-effect-free and short.

## Switch Statements

- Put `switch (x) {` and each `case Y:` on its own line; indent case bodies with 3 spaces.
- When all enum cases are handled and no default is intended, use a sentinel at the end so the compiler is satisfied: `NO_DEFAULT;` (e.g. `#define NO_DEFAULT default: if (0)`). Then close with `}`.
- Use `case Y: { ... }` when a case needs block scope (e.g. declarations). Use `break` or `return` in each case as appropriate.
- Optional: for simple case/return pairs, a local macro can reduce repetition: `#define CASE(t,r) case t: return r;`

## Error Handling

- **Fatal errors**: Use a single `ERROR(...)`-style macro that prints the message, file, and line, then exits (e.g. `exit(1)`). Use for allocation failures or impossible states.
- **Recoverable failure**: Use a return-code type (e.g. `RETCODE`: `RET_OK`, `RET_ERROR`, `RET_NO_SPACE`) for functions that can fail; document return values. Check and propagate in callers.

## Include Order

- **In .c**: Own header first (`#include "module.h"`), blank line, then system includes (`<...>`), then project/local includes (`"..."`). Group logically if many.
- **In .h**: After guard, system includes then project includes. Only include what the header needs for its declarations.

## Source File (.c) Layout

1. License/header block
2. `#include "module.h"` then other includes
3. Optional: local `#define` macros used only in this file (e.g. helpers, sentinels)
4. Optional: forward declarations of static and non-static functions used before definition
5. Function definitions (public then static, or logical order)

## Shared Types

- Cross-module enums (e.g. `TYPE`, `RETCODE`) and shared constants belong in a common header (e.g. `types.h`, `defines.h`). Include that header where needed; avoid redefining in multiple modules.

## Globals

- Use sparingly. Prefer passing context (e.g. `Interpret *p_interpret`) over file-scope globals.
- Name file-scope globals with `UPPER_SNAKE` or a leading underscore for “module private” (e.g. `TOKEN_ID_COUNTER`, `LIST_GARBAGE`).

## Multi-line Macros

- Use backslash continuation; indent continuation lines (e.g. tab or 3 spaces). Parenthesize arguments and the whole expansion to avoid precedence bugs.

## Quick Checklist

- [ ] Types PascalCase, functions/variables snake_case with prefixes
- [ ] 3-space indent, 80-char lines, K&R braces
- [ ] Pointer asterisk on variable name
- [ ] Return type on own line; parenthesized return values
- [ ] Header guards UPPERCASE from filename
- [ ] Static/private functions prefixed with `_`
- [ ] Callbacks (void* used as callback) suffixed with `_cb`
- [ ] Structs: one member per line; self-ref use `struct Name_` tag
- [ ] One module per file: foo.h/foo.c for main type + elem + iterator
- [ ] Every type has `type_new` and `type_delete`; iterators have `typeiterator_new`/`_delete`
- [ ] Header order: guard, includes, macros, enums, structs, new/delete then rest
- [ ] Accessors: `module_get_*` / `module_set_*`; switches use `NO_DEFAULT` when exhaustive
- [ ] Fatal errors via `ERROR(...)`; recoverable via RETCODE or documented return
- [ ] .c includes: own header first, then system, then project; optional forward decls
- [ ] Shared enums in one header; globals minimal and named UPPER or _prefix
