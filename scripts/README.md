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
