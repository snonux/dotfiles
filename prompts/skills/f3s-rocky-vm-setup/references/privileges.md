# User and Privileges

**`root`** — full root, used for package installs and Rex tasks.

**`paul`**
- **Removed from `wheel`** group. No general `sudo` access.
- May run the privileged commands in `update::tools` without a password: the
  five exact global npm installs and `/usr/local/bin/amp update`.
- Home: `/home/paul`
- Git repos: `~/git/` (cloned via local `r0`/`r1`/`r2` remotes)

## Sudoers config

`/etc/sudoers.d/update-coding-agents` defines a `UPDATE_TOOLS` command alias
for these commands only:

```
/usr/bin/npm install -g @openai/codex
/usr/bin/npm install -g @google/gemini-cli
/usr/local/bin/amp update
/usr/bin/npm install -g opencode-ai
/usr/bin/npm install -g @earendil-works/pi-coding-agent
```

`/usr/bin/doas` is a compatibility wrapper around `sudo`, so `update::tools`
uses the same policy. No other sudo privileges are granted. The `wheel-nopasswd`
file was removed and paul was removed from the `wheel` group.
