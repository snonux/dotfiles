# User and Privileges

**`root`** — full root, used for package installs and Rex tasks.

**`paul`**
- **Removed from `wheel`** group. No general `sudo` access.
- May run the privileged commands in `update::tools` without a password: five
  exact global npm installs, including `@ampcode/cli`.
- Home: `/home/paul`
- Git repos: `~/git/` (cloned via local `r0`/`r1`/`r2` remotes)

## Sudoers config

`/etc/sudoers.d/update-coding-agents` defines a `UPDATE_TOOLS` command alias
for these commands only:

```
/usr/bin/npm install -g @openai/codex
/usr/bin/npm install -g @google/gemini-cli
/usr/bin/npm install -g @ampcode/cli
/usr/bin/npm install -g opencode-ai
/usr/bin/npm install -g @earendil-works/pi-coding-agent
```

`/usr/bin/doas` is a compatibility wrapper around `sudo`, so `update::tools`
uses the same policy. The `wheel-nopasswd` file was removed and paul was removed
from the `wheel` group.

`/etc/sudoers.d/drop-caches` allows paul to run the dtail benchmark cache-drop
helper without a password:

```
paul ALL=(root) NOPASSWD: /usr/local/sbin/drop-caches
```

The script is installed root-owned at `/usr/local/sbin/drop-caches` (copy of
`~/git/dtail/benchmarks/drop_caches.sh`: `sync; echo 3 > /proc/sys/vm/drop_caches`).
The sudoers rule deliberately does not point at the paul-writable repo copy —
that would allow arbitrary root execution via script edits. The dtail Makefile
`drop-caches` target prefers the installed path and falls back to
`sudo ./benchmarks/drop_caches.sh` on hosts without it.

`/etc/sudoers.d/ior` separately allows selected IOR build and integration-test
commands. Its entries are not part of the updater policy. They need remediation:
the IOR executables are below Paul's writable home directory, so the current
`SETENV: NOPASSWD` rules can provide arbitrary root execution; one referenced
test executable is also absent. Do not describe Paul's sudo access as fully
restricted until those entries have been replaced with a safe design.
