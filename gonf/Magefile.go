//go:build mage

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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

// Install builds and installs the binary to $GOPATH/bin (or ~/go/bin).
func Install() error {
	fmt.Println("installing...")
	if err := Build(); err != nil {
		return err
	}
	gopath := os.Getenv("GOPATH")
	if gopath == "" {
		gopath = filepath.Join(os.Getenv("HOME"), "go")
	}
	dest := filepath.Join(gopath, "bin", binName)
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return err
	}
	fmt.Println("→", dest)
	return run("cp", "-f", binName, dest)
}
