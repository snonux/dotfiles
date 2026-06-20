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

## References

Load the reference that matches the question; the Quick Checklist below is the at-a-glance summary.

| Reference | Covers |
|-----------|--------|
| [naming-and-formatting.md](references/naming-and-formatting.md) | Naming conventions, formatting rules, function-definition layout, comment style |
| [files-and-headers.md](references/files-and-headers.md) | Header guards, file/license headers, struct formatting, header/source layout order, include order, shared types |
| [module-organization.md](references/module-organization.md) | One module per file, `new_`/`delete` lifecycle, iterators, callbacks, accessor macros |
| [code-body-conventions.md](references/code-body-conventions.md) | Switch statements, error handling, globals, multi-line macros |

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
