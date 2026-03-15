# dotfiles

These are all my dotfiles. I can install them locally on my laptop and/or workstation as well as remotely on any server.

For local installation, also have a read through https://blog.ferki.it/2023/08/11/local-management-with-rex/

## AI prompts

Prompts are managed from `~/Notes/Prompts` and linked by `home_prompts` into each tool config directory.

- Commands source of truth: `~/Notes/Prompts/commands`
- Skills source of truth: `~/Notes/Prompts/skills`
- Codex CLI slash command path: `~/.codex/prompts`
- Shared agent prompt paths: `~/.agents/{commands,skills}`
- Codex CLI runtime config: `~/.codex/config.toml`
- OpenCode runtime config: `~/.config/opencode/opencode.json` via `rex home`, using `OLLAMA_HOST` from `fish/conf.d/ai.fish` when available
