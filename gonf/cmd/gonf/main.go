package main

import (
	"os"

	"codeberg.org/snonux/dotfiles/gonf/internal/tasks"
	. "github.com/snonux/gonf/api"
)

func main() {
	RegisterMethods(tasks.Home{}, WithPrefix("home_"))
	RegisterMethods(tasks.Pkg{}, WithPrefix("pkg_"), WithGroupWhen(ProfileIs("fedora")))
	Task("home", "Install all home_* configuration", func() {
		_ = Run(Matching("^home_")...)
	})
	os.Exit(CLI())
}
