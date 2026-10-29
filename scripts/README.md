# Scripts installed to my ~/scripts

Mostly quick-n-dirty ones!

`ai-usage` prints a coloured terminal summary of subscription usage for
both the signed-in ChatGPT account's Codex rate limits and the signed-in
Claude Code subscription (5-hour and 7-day windows). Use `--format json` for
machine-readable data (one top-level `codex` and `claude` object each) or
`--format remaining` for one `label percent` line per window. Colours are
automatic for a terminal; use `--color always` or `--color never` to
override that. Codex limits come from the local Codex app server, so the
ChatGPT credential is never read; Claude limits come from the Anthropic
usage API with Claude Code's own OAuth token, which is never printed.

`harness-watch` keeps coding-agent harness panes in tmux running unattended.
It watches every pane of every tmux session whose name starts with `A-` and,
when a pane shows `Selected model is at capacity`, sends `continue` + Enter —
at most once per pane per 30 minutes. Subcommands: `start`, `stop`,
`status`, `once`. State and logs live in `~/.cache/harness-watch/`.
