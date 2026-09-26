---
name: increment-version-and-push
description: Increment the project version, update the F-Droid changelog if the project has one, tag it in git, commit, and push.
---

# Increment version and push

Increment the version of the project, update the F-Droid "What's new" changelog
if applicable, tag it in git, commit, and push.

## When to Use

- Use this skill when the user wants to bump the version and release/push a project.

## Instructions

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
  git tag matching the new version, and push both the commit and the tag.

## F-Droid changelog

Applies when the project has a fastlane store listing:
`find . -path '*/fastlane/metadata/android/*/changelogs' -not -path '*/build/*'`.
If nothing is found, skip this section. The F-Droid repo
(github.com/snonux/fdroid) reads the listing from the release tag, so the
changelog must be in the tagged commit; it cannot be fixed afterwards without
retagging.

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
