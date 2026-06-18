---
name: increment-version-and-push
description: Increment the project version, tag it in git, commit, and push.
---

# Increment version and push

Increment the version of the project, tag it in git, commit, and push.

## When to Use

- Use this skill when the user wants to bump the version and release/push a project.

## Instructions

- For Go-based projects, look for the `internal/version.go` file.
- We use semantic versioning: `x.y.z`.
  - For small changes (including minor feature tweaks, config/default-value updates, and bug fixes), increment only `z` (the patch version). When in doubt, prefer a patch bump.
  - For significant new features, increment `y` (the minor version) and reset `z` to 0.
  - Never increment `x` (the major version) unless explicitly specified.
- Commit the version change, create a git tag matching the new version, and push both the commit and the tag.
