# Renaming, Folding and Deleting Skills

Moving a skill breaks things outside its own directory. Follow this order so
nothing is lost and nothing is left pointing at the old name.

## 1. Inventory before touching anything

```sh
# every file of the skill, and every mention of its name anywhere
find <skill> -type f | sort
grep -rnI '<skill-name>' ~/git/dotfiles ~/git/conf --exclude-dir=.git
```

Places that reference skills besides other skills:

- `prompts/commands/*.md` (e.g. the `load-skill` examples)
- `prompts/sharable.md` (the list of shareable skills)
- `fish/conf.d/*.fish` comments that name a skill path
- docs in other repos, notably `~/git/conf` (`f3s/docs/`, READMEs)
- `plans/` and `notes/` are historical: add a superseded note, do not rewrite

The gitignored `synced/` directory under the skills root is not part of the
collection; leave it out of every sweep.

## 2. Move with a script, not by hand

For more than a couple of files, write a one-off script that:

1. Maps each old path to its new path (and, for a file that is being split,
   each heading anchor to the part that now holds it).
2. Rewrites every relative markdown link by **resolving it from the old
   location** and re-expressing it relative to the new one. Do this for the
   moved files and for every file that links to them.
3. Strips the frontmatter when a former `SKILL.md` becomes a reference, and
   adds an H1 if the body had none.
4. Asserts instead of guessing: every line of a split file lands in exactly one
   part, every replacement pattern matches.

## 3. Fix the prose the script cannot see

Links are mechanical; wording is not. Grep the moved files for:

- the old skill names in plain text ("the `x` skill's `y.md`")
- "this skill", "sibling skill", "hub" wording that no longer fits a reference
- "section N", "§N", "see above", "see below", "this document" in files that
  were split (see the pitfalls in [sub-division.md](sub-division.md#pitfalls-when-splitting-a-file))

## 4. Carry the triggers over

A folded skill loses its own description. The surviving skill's description
must cover the trigger phrases of everything it absorbed, and its `SKILL.md`
must route to each former skill in one line.

## 5. Verify

```sh
python3 scripts/audit_skills.py --extra ../commands --gone <old-name> [<old-name> ...]
```

Then prove nothing was dropped: compare the non-blank lines of the old files
(`git show HEAD:<path>`) with the new tree. Only frontmatter, rewritten links
and deliberately rewritten index text should be missing.

## 6. Commit

One commit for the move, via `commit-skills`. Deleting a skill is recoverable
from git history, but still only on the user's explicit request.
