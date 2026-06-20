# Files and Headers

How to lay out header and source files: guards, license blocks, struct
formatting, header/source ordering, include order, and shared-type placement.

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

## Header Layout Order

1. Header guard
2. `#include` (system then project/local)
3. Macros and accessor macros for the type
4. Enums (if any)
5. Struct typedefs (element/helper, then main type, then iterator/state)
6. Function declarations: `_new` / `_delete` first, then the rest (grouped logically)

Optional: close with `#endif /* GUARD_H */` for clarity.

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
