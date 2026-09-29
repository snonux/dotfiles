# Dotfiles code-quality audit — 2026-09-28

Scope: the entire tracked dotfiles repository, including fish startup/functions,
shell scripts, application configs, prompts/skills, and `gonf/`. The sibling
`~/git/gonf` checkout was consulted only for the recipe API. This is an audit;
no runtime behavior was changed. The existing edit to
`fish/conf.d/taskwarrior.fish` was preserved.

The `auditing-code-quality` workflow stamped local start tag
`audit/2026-09-28` at `73910480903bb9db68ff638e8c601ef059f340ab`.
Eleven findings were filed with `ask` before workspace permissions changed.
Thereafter `ask` could not create `.git/hexai-ask.lock` because `.git` became
read-only. Remaining findings below need individual `+bugfix` tasks, followed
by the audit closure gate and dependent tagging task required by the skill.
Do not treat the start tag as the finished audit marker.

## Confirmed defects already filed

| Severity | ID | Location | Failure and correction |
| --- | --- | --- | --- |
| High | `in2` | `fish/conf.d/taskwarrior.fish:112` | `bd-*.txt` includes `bd-compacted.txt`; cleanup removes the newly installed compacted note and then deletes source tasks. Exclude destination before cleanup. |
| High | `jn2` | `fish/conf.d/taskwarrior.fish:401` | Old completed `+agent` tasks are deleted even if SQLite archive write fails or is incomplete. Require validated archive success first. |
| High | `kn2` | `fish/conf.d/utils.fish:65` | `dedup` and `dedup_no_bak` can replace a file after failed conversion; reruns can also rely on a stale backup. Validate temporary output and use recoverable backup/replacement. |
| Medium | `ln2` | `fish/conf.d/taskwarrior.fish:622` | Task description `%` is parsed as a `printf` directive, truncating/corrupting Gos queue text. Use a fixed format string. |
| Medium | `mn2` | `fish/conf.d/quicklog.fish:181,221` | Failed pending-task export or `jq` parse silently leaves empty retry-dedup state. Retain source and fail the import on preload failure. |
| Medium | `nn2` | `fish/conf.d/tmputils.fish:71` | `tmpgrep` invokes nonexistent `tmcpat` (exit 127); call the intended `tmpcat`. |
| Medium | `on2` | `fish/conf.d/config.fish:8` | Every fish startup prepends the same six universal PATH entries, growing duplicates. Update paths idempotently while preserving order. |
| Medium | `pn2` | `fish/conf.d/supersync.fish:18` | Missing `gitsyncer` binary still advances the weekly stamp because a false fish `if` without `else` returns zero. Stamp only on sync success. |
| Medium | `qn2` | `fish/conf.d/supersync.fish:71` | Failed substeps are ignored; the final daily stamp suppresses retry. Aggregate statuses before stamping. |
| Medium | `rn2` | `fish/conf.d/taskwarrior.fish:542` | Full `+random` slots return before the promised `+maybe` replenishment. Check `+maybe` before that return. |
| Medium | `sn2` | `gonf/home/home.go:250` | `home` aggregate pulls privileged `system_uptimed` through `home_goprecords_upload`. Documented `./gonf.sh -n home` fails on earth without elevation. Reconcile dependency and invocation while retaining the upload prerequisite. |

## Confirmed defects still to file

Create one `+bugfix` task per row with the stated location and symptom; these
are separate failure modes. The first two were reproduced with a mocked HTTP
response and by tracing the destination key respectively.

| Severity | Location | Failure and correction |
| --- | --- | --- |
| High | `scripts/immich-upload:123-144` | `upload_file` logs HTTP 4xx/5xx or curl failure, then returns zero via `rm`; callers report success with missing images. Propagate and aggregate failures. |
| High | `scripts/immich-export:70-86` | Two assets in one account with the same `originalFileName` map to one destination; the second is silently skipped. Include asset identity in destination naming. |
| Medium | `scripts/immich-upload:73-78` | EXIF `2024:01:15 10:30:00+03:00` becomes `2024-01-15T10:30:00.000Z`, shifting time by three hours. Convert explicit offsets to UTC and define a policy for no-zone timestamps. |
| Medium | `scripts/immich-upload:163-179,277` | Filenames are embedded raw in JSON and transported with newline/tab-delimited records; quotes invalidate JSON and newlines split records. Encode JSON and use NUL-safe file enumeration. |
| Medium | `scripts/stabilize-video:87-88,121-143` | Inputs from different directories with the same basename share one parallel `.trf` path. Give each input a unique transform file. |
| Medium | `scripts/stabilize-video:103-105,145,159-171` | Failed encode/decode leaves a final output that the next run skips; decode failure also ends with exit zero. Encode to a temporary path, verify, then rename and return failure on invalid output. |
| Medium | `scripts/audit-due:79-85` | Documented cumulative insertions+deletions is implemented as a net tree diff. Edit/revert history can count as zero churn. Sum per-commit numstats since the marker. |
| Low | `scripts/brokenlinkfinder:33-35` | Root-relative and `./` links are concatenated to the whole page URL; `/about` on `/blog/page` becomes `/blog/page/about`. Resolve with `URI.join`. |
| Low | `tmux/tmux.conf:15,21` | Second `bind-key H` shadows resize-left. Pick a separate key or remove the dead binding. |
| Low | `scripts/pihole-dns-toggle:121-146` | An unrecognized argument enters `toggle|*`, so a typo changes DNS. Reject unknown actions. |
| Low | `fish/conf.d/taskwarrior.fish:129,205` | `touch` reuses interrupted `.tmp.1` files in maybe/wins exports; stale lines can enter the next note. Create a fresh unique temporary file or truncate first. |

## Simplification and dead-code candidates

- `fish/conf.d/k8s.fish:12-60` repeats pod selection across six wrappers; a
  common selector would reduce drift. `fish/conf.d/editor.fish:39-84` repeats
  lock/open behavior; both can be consolidated while preserving flags.
- `fish/conf.d/utils.fish:60-88` duplicates deduplication code. Consolidate
  together with the high-severity safety fix above.
- `scripts/immich-upload:112,158` declares unused `response` and `check_json`
  locals; they can be removed during an upload-path cleanup.
- `fish/conf.d/games.fish` contains only a newline. `taskwarrior::normalize_tags`
  and `supersync::is_it_time_to_sync` have no in-repo callers. Interactive or
  external callers may exist, so verify live usage before removing either.
- `systemd-user/home-backup.service` and `.timer` are legacy units that
  `home_systemd_user` now removes. The separate manual `home-backup` script is
  still documented and should remain unless its usage is checked.
- `gonf/home/home.go:227-229` installs `quicklog-drain` separately from
  `home_scripts`. This also supports standalone `home_systemd_user`, so the
  duplication is intentional unless task dependencies are redesigned.
- `gonf/README.md:3,57,75` has stale version/task-count text and says
  WireGuard units remain disabled; `go.mod` pins v0.24.0, `-list` has 38
  entries, and `system/system.go:68` enables those units. Update docs.
- `staticcheck` reports ST1001 dot imports in five handwritten gonf Go files;
  these are readability issues, with no demonstrated behavioral fault.

## Checks and close-out

All fish files passed `fish -n`; Bash scripts passed `bash -n`. ShellCheck
warnings were reviewed; the test fixture `done` warning is a false positive.
`gonf` passed `go build ./...`, `go vet ./...`, `errcheck ./...`, and `gofmt -l .`.
User systemd units passed `systemd-analyze verify --user`. The two plain JSON
config files parsed with `jq`; `waybar/config.jsonc` contains comments and is
not plain JSON. The 46 prompt skills have descriptions and are below the
500-line guideline; all real relative Markdown links resolve (the apparent
misses are example links inside fenced code blocks). No gonffile unit tests
were run, per the request.

After the remaining bug tasks are filed, create one `+audit` gate depending
on all finding tasks, annotate it with focused verification commands, then
create a final `+audit` task depending on the gate. That last task must use
the audit-tagging skill to move the exact `audit/2026-09-28` tag to post-fix
HEAD and push the end marker only after all fixes and verification are done.
