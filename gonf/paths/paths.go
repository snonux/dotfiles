// Package paths holds filesystem roots used by configuration tasks.
package paths

import (
	"fmt"
	"os"
	"path/filepath"

	. "github.com/snonux/gonf/api"
)

// Controller-side source roots used when declaring resources. They are read
// on the controller when a plan is recorded; destination paths are built
// with Home in the tasks themselves. Dot is this repository's checkout:
// ~/git/dotfiles, or GONF_DOTFILES_ROOT when set, which gonf.sh sets to the
// checkout it runs from so a second worktree records its own files.
var (
	Dot          = sourceRoot("GONF_DOTFILES_ROOT", Home("git/dotfiles"))
	DotPrivate   = Home("git/conf_private/dotfiles")
	NotesPrompts = Home("Notes/Prompts")
)

// sourceRoot returns the absolute path named by the environment variable
// env, or fallback when env is unset or empty. A relative override would
// depend on the recipe's working directory (gonf.sh changes into ./gonf),
// so it fails at startup instead.
func sourceRoot(env, fallback string) string {
	root := os.Getenv(env)
	if root == "" {
		return fallback
	}
	if !filepath.IsAbs(root) {
		panic(fmt.Sprintf("%s=%q must be an absolute path", env, root))
	}
	return filepath.Clean(root)
}
