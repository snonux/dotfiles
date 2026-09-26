// Package paths holds filesystem roots used by configuration tasks.
package paths

import (
	"fmt"
	"os"
	"path/filepath"

	. "github.com/snonux/gonf/api"
)

// Controller-side source roots, read on the controller when a plan is
// recorded (SyncDir/InstallFile sources, optional-source checks). Dot is this
// repository's checkout: ~/git/dotfiles, or GONF_DOTFILES_ROOT when set,
// which gonf.sh sets to the checkout it runs from so a second worktree
// records its own files.
var (
	dotRoot          = sourceRoot("GONF_DOTFILES_ROOT", Home("git/dotfiles"))
	dotPrivateRoot   = Home("git/conf_private/dotfiles")
	notesPromptsRoot = Home("Notes/Prompts")
)

// Dot returns rel inside the dotfiles checkout: Dot("helix/*").
func Dot(rel string) string { return dotRoot + "/" + rel }

// DotPrivate returns rel inside the private dotfiles checkout.
func DotPrivate(rel string) string { return dotPrivateRoot + "/" + rel }

// NotesPrompts returns rel inside the prompts notes.
func NotesPrompts(rel string) string { return notesPromptsRoot + "/" + rel }

// Destination-side roots: symlink targets that must point into the
// destination's own checkout and notes. DestHome records ${HOME}, which
// gonf expands on the destination, so the same plan works for /home/paul
// on Linux and /Users/paul on macOS. A GONF_DOTFILES_ROOT override is an
// absolute path of the machine gonf.sh runs on and is used as is.
var (
	destDotRoot          = destRoot("GONF_DOTFILES_ROOT", DestHome("git/dotfiles"))
	destNotesPromptsRoot = DestHome("Notes/Prompts")
)

// DestDot returns rel inside the destination's dotfiles checkout, for
// symlink targets: DestDot("bash/bashrc").
func DestDot(rel string) string { return destDotRoot + "/" + rel }

// DestNotesPrompts returns rel inside the destination's prompts notes.
func DestNotesPrompts(rel string) string { return destNotesPromptsRoot + "/" + rel }

// destRoot is sourceRoot for a destination path: the override when set,
// otherwise the ${HOME}-relative fallback.
func destRoot(env, fallback string) string {
	if os.Getenv(env) == "" {
		return fallback
	}
	return sourceRoot(env, fallback)
}

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
