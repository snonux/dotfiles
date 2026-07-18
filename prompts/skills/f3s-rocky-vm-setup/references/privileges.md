# User and Privileges

**`root`** — full root, used for package installs and Rex tasks.

**`paul`**
- **Removed from `wheel`** group. No general `sudo` access.
- **Only** allowed to run without password:
  ```
  /home/paul/scripts/update-coding-agents
  ```
- Home: `/home/paul`
- Git repos: `~/git/` (cloned via local `r0`/`r1`/`r2` remotes)

## Sudoers config

```
paul ALL=(root) NOPASSWD: /home/paul/scripts/update-coding-agents
```

No other sudo privileges. The `wheel-nopasswd` file was removed and paul was removed from the `wheel` group.
