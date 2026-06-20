# Module Organization

How modules ("classes") are structured: one module per file pair, the
`new_`/`delete` lifecycle, iterators, callbacks, and accessor macros.

## One Module per File

- **One logical "class" (module) per file pair**: `foo.h` + `foo.c` for the main type and everything that belongs to it.
- **File named after the main type**: `list.h`/`list.c` for List, `token.h`/`token.c` for Token.
- **Related types in the same file**: the main type, its element/node type (e.g. `ListElem`), and any iterator or state type (e.g. `ListIterator`, `ListIteratorState`) live in the same header and implementation. Do not split each type into its own file.
- **Enums** that are part of the module (e.g. `TokenType`, `HASH_OP`) stay in that module's header.

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

## Accessors and Macros

- **Naming**: `module_get_field(obj)`, `module_set_field(obj, val)` (e.g. `token_get_val`, `symbol_set_val`). Use macros in the header for trivial access; use functions for non-trivial logic.
- Simple accessors: `list_first(l)`, `hash_get_cur_size(hash)`. Keep macros side-effect-free and short.
