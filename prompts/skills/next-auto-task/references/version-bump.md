# Batched version bump

Read this when you are leaving a project, or it has no due-window-eligible
`+auto` task left, and you completed product-code tasks there in this run.

- Load `increment-version-and-push` (and `references/fdroid-release.md` when relevant).
- **Do not bump after every task.** After each completed product-code task, remember that the project may need a release. Run the bump **once** when leaving the project or when that project has no further due-window-eligible `+auto` tasks — covering product commits since the previous version tag (they may already be pushed; the batch is about **untagged** work, not unpushed).
- **Applicable when all of these hold:**
  - The repo is a **shippable app** with a documented release path: Flutter/`pubspec.yaml` + Android (especially snonux F-Droid apps), or AGENTS.md/README clearly describes releasing this app — not a library/CLI that merely has a version file, **and**
  - Since the last version tag there are product/runtime or user-facing commits from this `/next-auto-task` run (not only `prompts/skills/`, docs-only, or chore/CI-only), **and**
  - HEAD is on the default branch (`main`/`master`), in sync with upstream except for the commits you are releasing, and free of unrelated dirty paths, **and**
  - You have not already created a version tag for this batch in the current run.
- When applicable: follow `increment-version-and-push` (patch by default; use that skill's minor-bump guidance for significant features), including F-Droid changelogs, tag, push commit+tag, and F-Droid publish hooks.
- When **not** applicable: skip versioning; still push task commits from step 2 when allowed.
- If applicability is unclear, skip the bump, say why, and push commits only.
