# Bash Error Handling and Safety

## Paranoid mode (`set -e`)

Enable `set -e` so the script exits on any unexpected non-zero status. Temporarily disable it around commands that are allowed to fail.

```bash
set -e

some_function () {
    # ... critical code ...

    set +e
    grep ... || true
    local -i ec=$?
    set -e

    if (( ec != 0 )); then
        : # handle expected non-match
    fi
}
```

## `pipefail`

Use `set -o pipefail` so the pipeline returns the status of the last command that exited non-zero, not just the last command.

```bash
set -o pipefail
command1 | command2 | command3
```

## `PIPESTATUS`

Capture `PIPESTATUS` into an array immediately after a pipeline to inspect each stage's exit code.

```bash
tar -cf - ./* | ( cd "$dir" && tar -xf - )
return_codes=("${PIPESTATUS[@]}")
if (( return_codes[0] != 0 )); then
    echo 'tar failed' >&2
fi
```

## Arithmetic and Comparisons

Use arithmetic evaluation `(( ))` or numeric comparison operators (`-gt`, `-lt`, `-eq`) to avoid unintended lexicographical comparison.

```bash
# Wrong: lexicographical
if [[ "$my_var" > 3 ]]; then

# Right: numeric
if (( my_var > 3 )); then
if [[ "$my_var" -gt 3 ]]; then
```

## Restricted Bash

Use `rbash` as a coarse sandbox for highly constrained environments.

```bash
rbash -c 'echo hi'
```

See `man bash` (RESTRICTED SHELL) for details and caveats.
