# Naming and Formatting

Naming conventions, formatting rules, function-definition layout, and comment
style. These are the line-by-line style rules applied when writing or reviewing
any C source.

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

## Comments

- Block comments: `/* ... */`
- Single-line: `// comment`
- Avoid trailing inline comments for non-trivial explanations; put notes on their own line(s) above or below.
