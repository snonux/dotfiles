---
name: purge-file-from-git
description: Completely remove a file from git history using git-filter-repo.
---

# Purge file from git

Completely remove a file from git history using git-filter-repo. This is a destructive operation that rewrites history and requires force-pushing.

## When to Use

- Use this skill when a file needs to be completely purged from the entire git history (e.g., secrets, large binaries, sensitive data).

## Instructions

The user will provide a file path (e.g., "secrets.env", "large-file.bin", "config/passwords.txt").

I'll purge the specified file from the entire git history. This is a **destructive operation** that will:

1. **Rewrite all commits** in the repository's history
2. **Change commit hashes** for affected commits and their descendants
3. **Require a force-push** if already pushed to remote
4. **Potentially cause issues** for collaborators who have cloned the repo

**Before proceeding, confirm with the user:**

1. **Is this branch shared with others?** If so, they'll need to re-clone or carefully rebase after this operation.
2. **Have you pushed this branch to a remote?** If yes, you'll need to force-push afterward.
3. **Do you want to proceed with rewriting the git history?**

Once confirmed:

### Process:

1. **Verify prerequisites**:
   - Check if `git-filter-repo` is installed (install if needed)
   - Check current git status

2. **Execute purge**:
   - Clean any previous filter-repo state
   - Use `git filter-repo --path <file_path> --invert-paths --force`
   - Restore the origin remote (filter-repo removes it as a safety measure)

3. **Ask about .gitignore**:
   - Prompt: "Would you like to add the file to .gitignore to prevent future accidental commits?"
   - If yes: Add the file to .gitignore and commit the change
   - If no: Skip this step

4. **Provide next steps**:
   - Explain how to force-push: `git push --force origin <branch>`
   - Warn about impact on collaborators
   - Provide recovery instructions for team members
