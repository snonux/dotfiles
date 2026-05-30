# Bash Function Patterns

## Function Naming and Namespacing

- Prefer the POSIX-compatible form: `name() { ... }`
- Emulate namespaces with `::`, e.g. `pkg::lang::action`.
- Use `FUNCNAME[0]` for self-aware logging.

```bash
log() {
    local -r callee=${FUNCNAME[1]}
    echo "$callee: $*" >&2
}
```

## Private / Internal Functions

Mark internal helpers with a leading underscore so the public API is obvious: `module::_helper`. This matches the convention used by many Bash projects.

```bash
# Public
foo::generate () { ... }

# Internal only
foo::_sort_entries () { ... }
```

## Function Arguments: Assign-then-Shift

Assign function arguments to named `local` variables immediately using `$1`, then `shift`. This makes adding and removing arguments easy without renumbering.

```bash
some_function () {
    local -r param_foo="$1"; shift
    local -r param_bar="$1"; shift
    local -r param_baz="$1"; shift
}
```

## Scope and Functions

- Functions declared inside other functions are global once defined.
- `export -f function_name` makes a function available in subshells (e.g. `xargs -P`).
- `local` variables have dynamic scope: they are visible down the call stack.

## Chaining Conditionals

Functions return exit statuses and can be chained in conditionals.

```bash
if deploy_check || smoke_test; then
    echo "All good."
else
    echo "Something failed." >&2
fi
```

## `case` for Multi-Branch String Dispatch

Replace long `if/elif` chains with `case ... esac` when matching literal string patterns. It is more readable, avoids quoting pitfalls, and performs exact matching.

```bash
case "$line" in
    '* ')
        html::make_list_item "$line"
        ;;
    '# '*)
        html::make_heading "$line" 1
        ;;
    '## '*)
        html::make_heading "$line" 2
        ;;
    *)
        html::make_paragraph "$line"
        ;;
esac
```
