package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"strconv"
	"strings"
)

// lineRange is an inclusive range of line numbers in the new version of a file.
type lineRange struct{ from, to int }

// changes maps a root-relative, slash-separated file path to the line ranges
// that differ from a git revision.
type changes map[string][]lineRange

// gitChanges lists the Go lines under root that differ between rev and the
// working tree. Untracked files are not in `git diff`; commit them or mark
// them with `git add -N` first. The prefixes are forced to a/ and b/ so that
// a user's diff.noprefix or diff.mnemonicPrefix setting cannot change the
// output that parseDiff expects.
func gitChanges(root, rev string) (changes, error) {
	cmd := exec.Command("git", "-C", root, "diff", "-U0", "--no-color", "--no-ext-diff",
		"--src-prefix=a/", "--dst-prefix=b/", "--relative", rev, "--", "*.go")
	out, err := cmd.Output()
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			return nil, fmt.Errorf("git diff %s: %v: %s", rev, err, bytes.TrimSpace(ee.Stderr))
		}
		return nil, fmt.Errorf("git diff %s: %w", rev, err)
	}
	return parseDiff(bytes.NewReader(out))
}

// parseDiff reads a unified diff produced with -U0. A "+++ " line is a file
// header only right after a "--- " line; anywhere else it is an added line
// whose content happens to start with "++ ".
func parseDiff(r io.Reader) (changes, error) {
	ch := changes{}
	var file, prev string
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 64*1024), 16*1024*1024) // allow very long source lines
	for sc.Scan() {
		line := sc.Text()
		switch {
		case strings.HasPrefix(line, "+++ ") && strings.HasPrefix(prev, "--- "):
			file = diffPath(line[4:])
		case strings.HasPrefix(line, "@@ ") && file != "":
			lr, err := parseHunk(line)
			if err != nil {
				return nil, err
			}
			ch[file] = append(ch[file], lr)
		}
		prev = line
	}
	return ch, sc.Err()
}

// diffPath turns "b/dir/file.go" into "dir/file.go". A deleted file
// ("/dev/null") has no new lines, so it maps to "" and its hunks are ignored.
func diffPath(s string) string {
	s = strings.Trim(strings.TrimSpace(s), `"`)
	if s == "/dev/null" {
		return ""
	}
	return strings.TrimPrefix(s, "b/")
}

// parseHunk reads the new-file side "+start[,count]" of a hunk header. A count
// of 0 is a pure deletion after line start, so the lines on both sides of the
// gap count as changed: removing a statement changes the function around it.
func parseHunk(line string) (lineRange, error) {
	fields := strings.Fields(line)
	if len(fields) < 3 || !strings.HasPrefix(fields[2], "+") {
		return lineRange{}, fmt.Errorf("malformed hunk header %q", line)
	}
	startStr, countStr, hasCount := strings.Cut(fields[2][1:], ",")
	start, err := strconv.Atoi(startStr)
	if err != nil {
		return lineRange{}, fmt.Errorf("malformed hunk header %q: %w", line, err)
	}
	count := 1
	if hasCount {
		if count, err = strconv.Atoi(countStr); err != nil {
			return lineRange{}, fmt.Errorf("malformed hunk header %q: %w", line, err)
		}
	}
	if count == 0 {
		return lineRange{start, start + 1}, nil
	}
	return lineRange{start, start + count - 1}, nil
}

// keepChanged returns the functions whose lines overlap a changed range.
func keepChanged(funcs []fn, ch changes) []fn {
	var kept []fn
	for _, f := range funcs {
		for _, r := range ch[f.file] {
			if f.startLine <= r.to && r.from <= f.endLine {
				kept = append(kept, f)
				break
			}
		}
	}
	return kept
}

// addBase fills in each function's complexity at rev by reading the old file
// with `git show`. A file that did not exist at rev leaves its functions
// marked as new.
func addBase(root, rev string, funcs []fn) {
	cache := map[string]map[string]int{}
	for i := range funcs {
		f := &funcs[i]
		if _, ok := cache[f.file]; !ok {
			out, err := exec.Command("git", "-C", root, "show", rev+":./"+f.file).Output()
			if err != nil {
				out = nil // new file: no base complexities
			}
			cache[f.file] = fileComplexities(out)
		}
		f.baseCC, f.hasBase = cache[f.file][f.name]
	}
}
