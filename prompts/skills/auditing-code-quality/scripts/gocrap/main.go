// Command gocrap ranks the functions of a Go module by CRAP score
// (Change Risk Anti-Patterns):
//
//	CRAP(f) = cc(f)^2 * (1 - cov(f))^3 + cc(f)
//
// cc is cyclomatic complexity (counted like gocyclo) and cov is the fraction
// of statements covered by tests, read from a `go test -coverprofile` file.
// A complex function with no tests scores high; one that is simple or well
// tested scores low. The audit skill uses the ranking to pick hotspots and to
// compare scores before and after fixes. The score points at code worth
// reading. It is not evidence of a defect by itself.
//
// It needs only the standard library, so it runs without installing gocyclo:
//
//	go test -coverprofile=/tmp/cover.out ./...
//	go -C <skill>/scripts/gocrap run . -root "$PWD" -cover /tmp/cover.out
//
// Without -cover every function counts as uncovered (worst case) and the
// COV% column shows "-". The same happens for functions that have no
// statements in the profile, e.g. packages that did not compile under test.
//
// -changed REV keeps only functions whose lines differ between REV and the
// working tree (`git diff REV`). Task reviews use it to apply a CRAP limit to
// the code a change touched rather than to the whole codebase.
package main

import (
	"flag"
	"fmt"
	"io"
	"os"
)

func main() {
	root := flag.String("root", ".", "module root (the directory containing go.mod)")
	cover := flag.String("cover", "", "coverprofile from `go test -coverprofile` (optional)")
	top := flag.Int("top", 20, "print only the N highest scores (0 = all)")
	minScore := flag.Float64("min", 0, "print only functions scoring at least this")
	changed := flag.String("changed", "", "only functions changed since this git revision")
	flag.Parse()

	if err := run(os.Stdout, *root, *cover, *changed, *top, *minScore); err != nil {
		fmt.Fprintln(os.Stderr, "gocrap:", err)
		os.Exit(1)
	}
}

// run loads the profile (if any), scores every function under root, keeps
// only changed ones when rev is set, and prints the ranking to w.
func run(w io.Writer, root, cover, rev string, top int, minScore float64) error {
	var prof profile
	if cover != "" {
		modPath, err := modulePath(root)
		if err != nil {
			return err
		}
		if prof, err = loadProfile(cover, modPath); err != nil {
			return err
		}
	}
	funcs, err := collectFuncs(root, prof)
	if err != nil {
		return err
	}
	if rev != "" {
		ch, err := gitChanges(root, rev)
		if err != nil {
			return err
		}
		funcs = keepChanged(funcs, ch)
	}
	printReport(w, rank(funcs, top, minScore))
	return nil
}
