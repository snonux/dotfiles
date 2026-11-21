package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// block is one coverage block of a coverprofile line:
// "file.go:startLine.startCol,endLine.endCol numStmts count".
type block struct {
	startLine, startCol, endLine, endCol int
	stmts, count                         int
}

// profile maps a module-relative, slash-separated file path to its blocks.
type profile map[string][]block

// modulePath reads the `module` directive from root/go.mod. Profile entries
// are named by import path, so the module path is what turns them back into
// paths relative to root.
func modulePath(root string) (string, error) {
	data, err := os.ReadFile(filepath.Join(root, "go.mod"))
	if err != nil {
		return "", fmt.Errorf("-cover needs -root to be a module root: %w", err)
	}
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 2 && fields[0] == "module" {
			return strings.Trim(fields[1], `"`), nil
		}
	}
	return "", fmt.Errorf("no module directive in %s/go.mod", root)
}

// loadProfile parses a coverprofile. The same block can appear more than once
// (several test binaries can cover one package), so duplicates are merged
// and the highest count wins: covered by any test means covered.
func loadProfile(file, modPath string) (profile, error) {
	f, err := os.Open(file)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	merged := map[string]map[block]int{}
	sc := bufio.NewScanner(f)
	for n := 1; sc.Scan(); n++ {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "mode:") {
			continue
		}
		name, b, err := parseBlock(line)
		if err != nil {
			return nil, fmt.Errorf("%s:%d: %w", file, n, err)
		}
		rel := strings.TrimPrefix(name, modPath+"/")
		mergeBlock(merged, rel, b)
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	return flatten(merged), nil
}

// mergeBlock records b under rel, keeping the highest count seen. The count
// is zeroed in the map key so that duplicate positions collapse.
func mergeBlock(merged map[string]map[block]int, rel string, b block) {
	if merged[rel] == nil {
		merged[rel] = map[block]int{}
	}
	count := b.count
	b.count = 0
	if old, ok := merged[rel][b]; !ok || count > old {
		merged[rel][b] = count
	}
}

func flatten(merged map[string]map[block]int) profile {
	prof := profile{}
	for rel, blocks := range merged {
		for b, count := range blocks {
			b.count = count
			prof[rel] = append(prof[rel], b)
		}
	}
	return prof
}

// parseBlock splits one profile line into its file name and block.
func parseBlock(line string) (string, block, error) {
	colon := strings.LastIndex(line, ":")
	if colon < 0 {
		return "", block{}, fmt.Errorf("malformed line %q", line)
	}
	var b block
	_, err := fmt.Sscanf(line[colon+1:], "%d.%d,%d.%d %d %d",
		&b.startLine, &b.startCol, &b.endLine, &b.endCol, &b.stmts, &b.count)
	if err != nil {
		return "", block{}, fmt.Errorf("malformed line %q: %w", line, err)
	}
	return line[:colon], b, nil
}

// coverage returns the covered fraction of the statements whose block starts
// inside [start, end] (line/column pairs), and false when no statement of
// that range is in the profile.
func (p profile) coverage(rel string, start, end [2]int) (float64, bool) {
	var total, covered int
	for _, b := range p[rel] {
		pos := [2]int{b.startLine, b.startCol}
		if before(pos, start) || before(end, pos) {
			continue
		}
		total += b.stmts
		if b.count > 0 {
			covered += b.stmts
		}
	}
	if total == 0 {
		return 0, false
	}
	return float64(covered) / float64(total), true
}

func before(a, b [2]int) bool {
	return a[0] < b[0] || (a[0] == b[0] && a[1] < b[1])
}

// fmtCov renders a coverage fraction as a percentage, or "-" when unknown.
func fmtCov(cov float64, known bool) string {
	if !known {
		return "-"
	}
	return strconv.FormatFloat(cov*100, 'f', 0, 64)
}
