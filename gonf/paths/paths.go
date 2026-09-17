// Package paths holds filesystem roots used by configuration tasks.
package paths

import . "github.com/snonux/gonf/api"

// Repo roots used when declaring resources.
var (
	Dot          = Home("git/dotfiles")
	DotPrivate   = Home("git/conf_private/dotfiles")
	NotesPrompts = Home("Notes/Prompts")
)
