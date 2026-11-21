# Where things live

Read this when applying changes after a review.

| Thing | Location | Check | Release |
|---|---|---|---|
| Skills | `~/git/dotfiles/prompts/skills/` (linked from `~/.claude/skills`, `~/.agents/skills`, `~/.pi/skills`) | `python3 skill-maintenance/scripts/audit_skills.py --extra ../commands` from the skills directory; fix every error and warning it reports for the skills you touched | `commit-skills` skill (commit and push) |
| Role cards | `agent-task-management/references/card-*.md` | at most 200 words each (the audit script warns) | with the skills |
| `ask` CLI | `~/git/hexai`, package `internal/askcli` | `go test ./internal/askcli`, `gofumpt -l`, `golangci-lint run ./internal/askcli/...` | `increment-version-and-push` skill, which also runs `mage install` |
| CRAP tool | `auditing-code-quality/scripts/gocrap/` and `crap-check.sh` | `go -C scripts/gocrap test -race ./...` | with the skills |
| pi workflow prompt | `~/git/hypr/pi/agent/extensions/agent-plan-mode/index.ts` (two prompt blocks) and `utils.ts` (plan-mode command patterns) | `bun build --no-bundle index.ts --outfile <tmp>` for a syntax check | commit and push `~/git/hypr`; pi picks it up on `/reload-runtime` |
| cursor-agent | uses the shared skills through `~/.cursor/skills`; `~/.cursor/commands` links to `~/git/dotfiles/prompts/commands`, which is empty since the commands became skills | nothing cursor-specific to maintain | with the skills |
| Session logs | `~/.claude/projects`, `~/.codex/sessions`, `~/.pi/agent/sessions`, `~/.cursor/projects/*/agent-transcripts` | read-only | never committed |

## Rules that held up

- **The worker card and the pi prompt are one text in two places.** Change
  both together.
- **A new `ask` subcommand needs three follow-ups:** `00-cli.md` in
  agent-task-management, `ASK_SUBS` in `scripts/scan_sessions.py`, and the
  plan-mode patterns in the pi extension's `utils.ts` if it changes task state.
- **Tasks carry old annotations.** A change to the standard "Agent workflow"
  annotation only affects new tasks. Either make the card override it (one
  line) or re-annotate pending tasks; the first is cheaper.
- **Write the failing test first** for tool changes, and try the released
  binary in a real repository afterwards (for worktree behaviour: a real
  `git worktree add`).
- **Tests that read the real `~/.cache` alias cache are flaky.** New `ask`
  tests use `useIsolatedTaskAliasCache`.
