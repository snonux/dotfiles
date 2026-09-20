# Project scope and task state

`ask` derives the Taskwarrior project from the git repository basename plus the
working directory relative to the repository root, joining segments with dots:

| Working directory | Project |
|---|---|
| `~/git/dotfiles` | `dotfiles` |
| `~/git/dotfiles/prompts` | `dotfiles.prompts` |
| `~/git/dotfiles/prompts/nested` | `dotfiles.prompts.nested` |

`ask add` stamps that exact project. Read commands include that project and its
descendants, but not sibling projects. Use `ask proj:<name> …` to override the
scope. Directory names containing dots are ambiguous in this hierarchy; avoid
them when relying on sub-project scoping. Existing flat tasks remain valid at
the repository root.

Only one task may be in progress within the current `ask` scope. From the
repository root this includes sub-project tasks; from a subdirectory it does
not include parent or sibling projects. If more than one task is unexpectedly
started, report the conflicting IDs and stop instead of selecting another.
