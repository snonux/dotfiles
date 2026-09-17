package main

import (
	"os"

	"codeberg.org/snonux/dotfiles/gonf/tasks"
	. "github.com/snonux/gonf/api"
	"github.com/snonux/gonf/cli"
)

func main() {
	RegisterMethods(tasks.HomeTasks{}, WithPrefix("home_"))
	RegisterMethods(tasks.Pkg{}, WithPrefix("pkg_"), WithGroupWhen(WhenProfile("fedora")))
	Aggregate("home", "Install all home_* configuration", "^home_")
	os.Exit(cli.CLI())
}
