# Mistake #16: Not using linters

#### TL;DR

To improve code quality and consistency, use linters and formatters.

A linter is an automatic tool to analyze code and catch errors. The scope of this section isn’t to give an exhaustive list of the existing linters; otherwise, it will become deprecated pretty quickly. But we should understand and remember why linters are essential for most Go projects.

However, if you’re not a regular user of linters, here is a list that you may want to use daily:

* https://golang.org/cmd/vet—A standard Go analyzer
* https://github.com/kisielk/errcheck—An error checker
* https://github.com/fzipp/gocyclo—A cyclomatic complexity analyzer
* https://github.com/jgautheron/goconst—A repeated string constants analyzer

Besides linters, we should also use code formatters to fix code style. Here is a list of some code formatters for you to try:

* https://golang.org/cmd/gofmt—A standard Go code formatter
* https://godoc.org/golang.org/x/tools/cmd/goimports—A standard Go imports formatter

Meanwhile, we should also look at golangci-lint (https://github.com/golangci/golangci-lint). It’s a linting tool that provides a facade on top of many useful linters and formatters. Also, it allows running the linters in parallel to improve analysis speed, which is quite handy.

Linters and formatters are a powerful way to improve the quality and consistency of our codebase. Let’s take the time to understand which one we should use and make sure we automate their execution (such as a CI or Git precommit hook).
