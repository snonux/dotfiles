// Package paths holds filesystem roots used by configuration tasks.
package paths

import "os"

// Roots used when declaring resources. Resolved once at package init from
// the process environment so task bodies stay free of os.Getenv calls.
var (
	Home       = os.Getenv("HOME")
	Dot        = Home + "/git/dotfiles"
	DotPrivate = Home + "/git/conf_private/dotfiles"
	NotesPrompts = Home + "/Notes/Prompts"
)
