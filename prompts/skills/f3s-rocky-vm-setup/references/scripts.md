# Scripts

## `update::tools`

The Fish function in `fish/conf.d/update.fish` updates user-owned Go tools and
the global npm coding agents. Its privileged calls use `/usr/bin/doas`, a local
compatibility wrapper for `sudo`; the exact commands are allowlisted in
`/etc/sudoers.d/update-coding-agents`. Amp Code is installed from the official
`@ampcode/cli` npm package.
