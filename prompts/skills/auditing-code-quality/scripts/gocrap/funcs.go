package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io"
	"io/fs"
	"math"
	"path/filepath"
	"sort"
	"strings"
)

// fn is one scored function.
type fn struct {
	name     string // "Func", "T.Method" or "(*T).Method"
	location string // module-relative "dir/file.go:line"
	cc       int
	cov      float64
	covKnown bool
	crap     float64
}

// crap computes the CRAP score. Unknown coverage counts as zero.
func crap(cc int, cov float64) float64 {
	c := float64(cc)
	return c*c*math.Pow(1-cov, 3) + c
}

// collectFuncs parses every non-test, non-generated Go file under root and
// scores each function declaration. vendor/, testdata/ and dot-directories
// are skipped because they are not the module's own maintained code.
func collectFuncs(root string, prof profile) ([]fn, error) {
	var out []fn
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if p != root && skipDir(d.Name()) {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(p, ".go") || strings.HasSuffix(p, "_test.go") {
			return nil
		}
		rel, err := filepath.Rel(root, p)
		if err != nil {
			return err
		}
		funcs, err := scoreFile(p, filepath.ToSlash(rel), prof)
		out = append(out, funcs...)
		return err
	})
	return out, err
}

func skipDir(name string) bool {
	return name == "vendor" || name == "testdata" || strings.HasPrefix(name, ".") ||
		strings.HasPrefix(name, "_")
}

// scoreFile scores the function declarations of one file.
func scoreFile(path, rel string, prof profile) ([]fn, error) {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, path, nil, parser.ParseComments)
	if err != nil {
		return nil, fmt.Errorf("parse %s: %w", rel, err)
	}
	if ast.IsGenerated(file) {
		return nil, nil
	}
	var out []fn
	for _, decl := range file.Decls {
		fd, ok := decl.(*ast.FuncDecl)
		if !ok || fd.Body == nil {
			continue // not a function, or an assembly-backed declaration
		}
		start, end := fset.Position(fd.Pos()), fset.Position(fd.End())
		f := fn{name: funcName(fd), location: fmt.Sprintf("%s:%d", rel, start.Line), cc: complexity(fd)}
		f.cov, f.covKnown = prof.coverage(rel, [2]int{start.Line, start.Column}, [2]int{end.Line, end.Column})
		f.crap = crap(f.cc, f.cov)
		out = append(out, f)
	}
	return out, nil
}

// complexity counts cyclomatic complexity like gocyclo: 1, plus one per
// if, for, range, non-default case or select clause, && and ||. Closures
// count toward the function that contains them.
func complexity(fd *ast.FuncDecl) int {
	cc := 1
	ast.Inspect(fd.Body, func(n ast.Node) bool {
		switch n := n.(type) {
		case *ast.IfStmt, *ast.ForStmt, *ast.RangeStmt:
			cc++
		case *ast.CaseClause:
			if n.List != nil {
				cc++
			}
		case *ast.CommClause:
			if n.Comm != nil {
				cc++
			}
		case *ast.BinaryExpr:
			if n.Op == token.LAND || n.Op == token.LOR {
				cc++
			}
		}
		return true
	})
	return cc
}

// funcName renders a declaration as Func, T.Method or (*T).Method, without
// type parameters, so names stay stable across baseline and re-check.
func funcName(fd *ast.FuncDecl) string {
	if fd.Recv == nil || len(fd.Recv.List) == 0 {
		return fd.Name.Name
	}
	return recvName(fd.Recv.List[0].Type) + "." + fd.Name.Name
}

func recvName(expr ast.Expr) string {
	switch t := expr.(type) {
	case *ast.StarExpr:
		return "(*" + recvName(t.X) + ")"
	case *ast.IndexExpr:
		return recvName(t.X)
	case *ast.IndexListExpr:
		return recvName(t.X)
	case *ast.Ident:
		return t.Name
	}
	return "?"
}

// rank sorts by descending score (location breaks ties for stable output)
// and applies the -min and -top filters.
func rank(funcs []fn, top int, minScore float64) []fn {
	sort.Slice(funcs, func(i, j int) bool {
		if funcs[i].crap != funcs[j].crap {
			return funcs[i].crap > funcs[j].crap
		}
		return funcs[i].location < funcs[j].location
	})
	kept := funcs[:0]
	for _, f := range funcs {
		if f.crap >= minScore {
			kept = append(kept, f)
		}
	}
	if top > 0 && len(kept) > top {
		kept = kept[:top]
	}
	return kept
}

// printReport writes a tab-separated table that pastes cleanly into task
// annotations and can be diffed between baseline and re-check.
func printReport(w io.Writer, funcs []fn) {
	fmt.Fprintln(w, "CRAP\tCC\tCOV%\tLOCATION\tFUNC")
	for _, f := range funcs {
		fmt.Fprintf(w, "%.1f\t%d\t%s\t%s\t%s\n",
			f.crap, f.cc, fmtCov(f.cov, f.covKnown), f.location, f.name)
	}
}
