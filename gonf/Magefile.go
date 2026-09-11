//go:build mage

package main

import (
	"fmt"
	"os"
	"os/exec"
)

const binName = "gonf"

func run(cmd string, args ...string) error {
	c := exec.Command(cmd, args...)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c.Run()
}

// Default builds the binary.
func Default() error {
	return Build()
}

// Deps downloads module dependencies (go mod download).
func Deps() error {
	fmt.Println("downloading dependencies...")
	return run("go", "mod", "download")
}

// Build compiles the gonf binary into the module root.
func Build() error {
	fmt.Println("building...")
	return run("go", "build", "-o", binName, "./cmd/gonf")
}
