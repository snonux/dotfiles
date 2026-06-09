# Notes

- The `claude` wrapper must **not** be a shell script calling the JS wrapper — that caused a fork bomb because `cli-wrapper.cjs` tried to exec the `claude` binary but found the script instead. Use a direct symlink or the npm-installed binary.
- Node.js is installed via `dnf module install nodejs:22/common` (pi 0.75.0+ requires Node >= 22.19.0).
- `amp` panics in non-TTY environments — that's expected for a TUI editor.
