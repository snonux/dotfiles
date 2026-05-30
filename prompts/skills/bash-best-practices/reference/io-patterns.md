# Bash I/O, Pipelines, and Data Processing

## Built-ins vs External Commands

- Prefer Bash built-ins for light text processing and arithmetic.
- Use external commands (`sed`, `awk`, `grep`, `cut`, `tr`, `bc`) for heavy or complex text processing.

```bash
# Prefer built-in
addition=$(( X + Y ))

# Prefer external for sophisticated transforms
substitution="$(echo "$string" | sed -e 's/^foo/bar/')"
```

## Process Substitution

Use `<(command)` and `>(command)` for treating command output as a file.

```bash
diff -u <(sort file1) <(sort file2)
tar cjf >(bzip2 -c > file.tar.bz2) foo
```

## `while read` with Process Substitution

When iterating over command output and modifying variables in the parent shell, use process substitution as the input source rather than piping into `while`. A pipe creates a subshell, so variable changes are lost.

```bash
# Good: changes to $count survive
local -i count=0
while IFS='' read -r line; do
    (( count++ ))
done < <(command)

# Bad: $count is lost because the while runs in a subshell
local -i count=0
command | while IFS='' read -r line; do
    (( count++ ))
done
```

### `IFS='' read -r line` for exact line preservation

Use `IFS='' read -r line` when reading lines you intend to preserve exactly, including leading and trailing whitespace. Without `IFS=''`, leading/trailing whitespace is stripped; without `-r`, backslashes are interpreted.

```bash
while IFS='' read -r line; do
    echo "$line"
done < file.txt
```

## Here-Documents and Here-Strings

Use here-docs and here-strings for multi-line or inline input.

```bash
# Here-document with variable interpolation
cat <<EOF
Hello $USER
EOF

# Literal here-document (no interpolation)
cat <<'EOF'
$USER is not expanded
EOF

# Here-string
if grep -q foo <<< "$VAR"; then
    echo match
fi
```

Use `<<-EOF` to strip leading tabs from the body.

### Prefer here-strings over `echo | command`

For single-line input, prefer `command <<< "$var"` instead of `echo "$var" | command`. It avoids an extra pipe, subshell, and process spawn.

```bash
# Good
tr '[:upper:]' '[:lower:]' <<< "$text"

# Avoid
echo "$text" | tr '[:upper:]' '[:lower:]'
```

## Input Placeholders and Redirection

- `-` as stdin/stdout placeholder for commands like `tar` and `cat`.
- Redirect via file descriptors explicitly (`2>/dev/null`, `1>&2`).
- Remember redirection order matters.

```bash
echo Foo 2>/dev/null 1>&2   # suppresses everything
```

## `/dev/tcp` Networking

Bash supports TCP via pseudo-files:

```bash
cat < /dev/tcp/time.nist.gov/13
exec 5<>/dev/tcp/google.de/80
```

## List Processing: Pipes over Arrays

For simple list processing, prefer pipelines over arrays. Pass data through stdout to the next stage and use stderr for logging.

```bash
main () {
    filter_lines |
        process_lines |
        postprocess_lines |
        generate_report
}
```

## Reading Files and Arrays

- **Read a whole file into a variable** without spawning `cat`: `cfg=$(<config.ini)`
- **Read lines into an array** safely with `mapfile` (aka `readarray`): `mapfile -t lines < file`
- **Assign formatted strings without a subshell** using `printf -v`: `printf -v msg 'Hello %s' "$USER"`

## Safe xargs with NULs

Avoid breaking on spaces/newlines by pairing `find -print0` with `xargs -0`:

```bash
find . -type f -name '*.log' -print0 | xargs -0 rm -f
```
