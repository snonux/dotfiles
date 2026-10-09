# timesamurai: hosts, storage, config, experiments and legacy import/export

## Hosts, storage, config

- Every entry is recorded for a host. Default: the current machine's
  hostname. `--host <name>` records elsewhere instead; it exists on
  `start`, `stop`, `add`, `sub`, `day-off`, `usebuffer`, and `import`
  (and as a *filter* on `list`/`search`; on `undo` it means something
  different — see [entries](entries.md)).
- `timesamurai work --store <dir>` overrides the JSONL store directory for
  the whole `work` command tree. **Use this for experiments** — see below.
- `timesamurai work --db <dir>` overrides the legacy `db.*.json` directory.
- `timesamurai --config <path>` selects a different config file.
- Config file: `$XDG_CONFIG_HOME/timesamurai/config.toml` (usually
  `~/.config/timesamurai/config.toml`). Precedence, highest first:
  command-line flags → `TIMESAMURAI_*` environment variables → config
  file → built-in defaults. `store_dir` defaults to
  `~/git/worktime/timesamuraidb`.
- `timesamurai completion bash|zsh|fish|powershell` prints a completion
  script.

## Safe experiments

To test any command without touching the real log, point at a throwaway
store:

```bash
timesamurai work --store /tmp/ts-test add 1h -d "experiment"
timesamurai work --store /tmp/ts-test report
rm -rf /tmp/ts-test
```

Do this when the user asks "what would happen if..." or before trying a
tricky `modify`/`delete`. Real data mutations (start/stop/add/sub/modify/
delete) should be made deliberately, one at a time, and verified.

## Legacy import/export (only when asked)

- `timesamurai work migrate` — one-shot import of the old Ruby
  `db.<host>.json` files into the JSONL store (`--force` to re-run).
- `timesamurai work export [--strict]` — rewrite legacy `db.<host>.json`
  from the JSONL store (keeps the old `worktime.rb` tool working).
- `timesamurai work import <file> [--host h]` — import report.txt-format
  lines as work/lunch/off entries.

Do not run these unless the user explicitly asks for a migration/export.
