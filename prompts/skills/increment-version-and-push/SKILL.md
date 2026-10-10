---
name: increment-version-and-push
description: Increment the project version, update the F-Droid changelog if the project has one, tag it in git, commit, push, and run mage install when available. Use when asked to bump the version, cut a release, or tag and push a new version.
---

# Increment version and push

Increment the version of the project, update the F-Droid "What's new" changelog
if applicable, tag it in git, commit, push, and install via Mage when the
project defines an `install` target.

## When to Use

- Use this skill when the user wants to bump the version and release/push a project.

## Instructions

- Check whether this app is published through the snonux F-Droid repo (see
  `references/fdroid-release.md`, section 1). If it is, follow that reference
  for the release steps. Where it contradicts this skill, the reference wins.
- Check the project's AGENTS.md / README first: if it documents a release
  procedure or a bump recipe (e.g. `just bump-version x.y.z` in a monorepo that
  keeps several version files in sync), follow that instead of editing version
  files by hand.
- For Go-based projects, look for the `internal/version.go` file.
- We use semantic versioning: `x.y.z`.
  - For small changes (including minor feature tweaks, config/default-value updates, and bug fixes), increment only `z` (the patch version). When in doubt, prefer a patch bump.
  - For significant new features, increment `y` (the minor version) and reset `z` to 0.
  - Never increment `x` (the major version) unless explicitly specified.
- Update the F-Droid changelog if applicable (see below) before committing.
- Commit the version change (and the changelog, in the same commit), create a
  git tag for the new version, and push both the commit and the tag.
  - **Exception, F-Droid apps: do not create or push the tag yourself.** Push
    only the commit, then start the app's Release workflow with the new tag
    as input (`gh workflow run release.yml --ref main -f tag=vX.Y.Z`); the
    workflow checks the version file and creates the tag on the branch head.
    Details and the fallback for a workflow without that step are in
    `references/fdroid-release.md`, section 4.
  - **Release tags always carry a leading `v`: `vX.Y.Z`** (e.g. `v0.39.3`),
    even when the version file stores the bare number (`const Version =
    "0.39.3"`). Never tag `0.39.3` — Go modules and the release workflows only
    recognise `v`-prefixed semver tags.
  - Before tagging, confirm with `git tag -l 'vX.Y.Z'` that the tag does not
    already exist, and push only that tag (`git push origin vX.Y.Z`) rather than
    `git push --tags`, so stray local tags are not published.
  - If you create a GitHub release, use the same `vX.Y.Z` tag and title.
- After the version has been incremented (so the working tree / tagged commit
  embeds the new version), run **`mage install`** when the project supports it
  (see below). Do this after the version files are updated; prefer after the
  commit and tag so the installed binary matches the release, and before or
  after push — push failure must not skip a successful local install.

## Mage install (optional)

Applies when the project root has a Magefile (`Magefile.go` or `magefile.go`)
**and** an `install` target. Skip this section entirely otherwise.

Detect the target (either is enough):

- `mage -l` lists a target named `install` (mage prints names in lowercase), or
- the Magefile defines `func Install(...)` (Go export; mage exposes it as
  `install`).

If present, run from the project root:

```sh
mage install
```

- Requires `mage` on `PATH`. If `mage` is missing, report that and skip — do
  not invent a `go install` substitute unless the project's AGENTS.md /
  README says to.
- Fail the skill if `mage install` exits non-zero (the release push may
  already have succeeded; surface the install error clearly).
- Do not invent other Mage targets (`build`, `devInstall`, etc.) here — only
  `install`.

## F-Droid changelog

Applies when the project has a fastlane store listing:
`find . -path '*/fastlane/metadata/android/*/changelogs' -not -path '*/build/*'`.
If nothing is found, skip this section. The F-Droid repo
(github.com/snonux/fdroid) reads the listing from the release tag, so the
changelog must be in the tagged commit; it cannot be fixed afterwards without
retagging. The Release workflow tags the head of `main` when it is started,
so the changelog has to be pushed before that run.

F-Droid shows `changelogs/<versionCode>.txt` as "What's new", where
`<versionCode>` is the **APK's** version code, and falls back to
`changelogs/default.txt` when no such file exists.

- Content: a few plain lines on what changed since the previous tag
  (`git log <prev-tag>..HEAD -- <app dir>`), written for users, not
  developers. At most 500 characters (`wc -c`). Mirror the style of the
  previous changelog.
- If the project uses `default.txt` only: rewrite it in place.
- If the project uses per-versionCode files (e.g. `101.txt`, `102.txt`):
  add new ones for the new version code, and keep the old files.
  - Split-per-ABI builds have one version code per APK, so write one file per
    ABI with the same text. Work out the actual APK codes from the build
    config and the project's AGENTS.md: Flutter's default is
    `abi * 1000 + build` (armeabi-v7a 1, arm64-v8a 2, x86_64 4), but some
    projects override it (e.g. quicklog uses `build * 10 + abi`, so build 12
    gives `121.txt`, `122.txt`, `123.txt`). A file named after the pubspec
    `+N` build number alone is never read in a split build.
  - Bump the build number (`+N` in pubspec.yaml / `versionCode`) if the bump
    step did not, since F-Droid needs it to strictly increase.
- Locales: update every locale directory that has a changelogs folder, or
  just `en-US` if it is the only one.
