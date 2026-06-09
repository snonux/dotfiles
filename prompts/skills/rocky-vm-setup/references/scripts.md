# Scripts

## `/home/paul/scripts/update-coding-agents`

```sh
#!/bin/sh
set -e
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi
echo "Updating Claude Code..."
npm update -g @anthropic-ai/claude-code @anthropic-ai/claude-code-linux-x64
echo "Updating pi coding agent..."
npm update -g @earendil-works/pi-coding-agent
echo "All coding agents updated."
```

Run as paul: `$ /home/paul/scripts/update-coding-agents`

Sudoers allows this specific script without a password. No other root access for paul.
