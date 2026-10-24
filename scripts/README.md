# Scripts installed to my ~/scripts

Mostly quick-n-dirty ones!

`ai-usage` prints a coloured terminal summary of subscription usage. It
currently reports the signed-in ChatGPT account's Codex rate limits and is
named to accommodate further providers. Use `--format json` for
machine-readable data or `--format remaining` for the primary allowance's
remaining percentage. Colours are automatic for a terminal; use
`--color always` or `--color never` to override that. It calls the local
Codex app server, so it never reads or prints the ChatGPT credential.
