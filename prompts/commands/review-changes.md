# /review-changes

**Description:** Review all uncommitted git changes (staged + unstaged), explain what they do and why, assess correctness, and write a review to REVIEW-COMMENTS.md.

---

## Prompt

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
