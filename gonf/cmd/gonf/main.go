package main

import (
	"os"

	"codeberg.org/snonux/dotfiles/gonf/home"
	"codeberg.org/snonux/dotfiles/gonf/pkg"
	. "github.com/snonux/gonf/api"
	"github.com/snonux/gonf/cli"
)

func main() {
	RegisterMethods(home.HomeTasks{})
	RegisterMethods(pkg.Pkg{}, WithGroupWhen(WhenProfile("fedora")))
	Aggregate("home", "Install all home_* configuration", "^home_")
	os.Exit(cli.CLI())
}
