---
name: review-changes
description: "Review staged and unstaged Git changes, assess correctness, and write REVIEW-COMMENTS.md. Use when explicitly invoked as review-changes to review the current repository before committing."
disable-model-invocation: true
---

# Review Changes

Run only when explicitly requested.

Review all uncommitted changes in this repository:

1. Run `git status`, `git diff --cached`, `git diff`, and `git log --oneline -10` to understand the current state.
2. Read the relevant source files for full context around each change.
3. For each modified file, explain:
   - What changed and why it's needed
   - Whether the change is correct
   - Any concerns or nits
4. Overwrite `REVIEW-COMMENTS.md` with a structured review covering:
   - Overview and motivation
   - Files changed (table)
   - Detailed assessment of each change
   - Summary with verdict
