# Code-Body Conventions

Conventions that apply inside function bodies and at file scope: switch
statements, error handling, globals, and multi-line macros.

## Switch Statements

- Put `switch (x) {` and each `case Y:` on its own line; indent case bodies with 3 spaces.
- When all enum cases are handled and no default is intended, use a sentinel at the end so the compiler is satisfied: `NO_DEFAULT;` (e.g. `#define NO_DEFAULT default: if (0)`). Then close with `}`.
- Use `case Y: { ... }` when a case needs block scope (e.g. declarations). Use `break` or `return` in each case as appropriate.
- Optional: for simple case/return pairs, a local macro can reduce repetition: `#define CASE(t,r) case t: return r;`

## Error Handling

- **Fatal errors**: Use a single `ERROR(...)`-style macro that prints the message, file, and line, then exits (e.g. `exit(1)`). Use for allocation failures or impossible states.
- **Recoverable failure**: Use a return-code type (e.g. `RETCODE`: `RET_OK`, `RET_ERROR`, `RET_NO_SPACE`) for functions that can fail; document return values. Check and propagate in callers.

## Globals

- Use sparingly. Prefer passing context (e.g. `Interpret *p_interpret`) over file-scope globals.
- Name file-scope globals with `UPPER_SNAKE` or a leading underscore for "module private" (e.g. `TOKEN_ID_COUNTER`, `LIST_GARBAGE`).

## Multi-line Macros

- Use backslash continuation; indent continuation lines (e.g. tab or 3 spaces). Parenthesize arguments and the whole expansion to avoid precedence bugs.
