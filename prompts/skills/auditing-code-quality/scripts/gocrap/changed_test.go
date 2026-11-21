package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestParseDiff(t *testing.T) {
	diff := strings.Join([]string{
		"diff --git a/p/a.go b/p/a.go",
		"--- a/p/a.go",
		"+++ b/p/a.go",
		"@@ -3,2 +3,4 @@ func A() {",
		"+++ an added line that starts with ++, not a header",
		"@@ -10 +12 @@",
		"@@ -20,3 +21,0 @@",
		"diff --git a/gone.go b/gone.go",
		"--- a/gone.go",
		"+++ /dev/null",
		"@@ -1,5 +0,0 @@",
	}, "\n")
	got, err := parseDiff(strings.NewReader(diff))
	if err != nil {
		t.Fatal(err)
	}
	want := changes{"p/a.go": {{3, 6}, {12, 12}, {21, 22}}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("parseDiff = %v, want %v", got, want)
	}
}

func TestParseHunkErrors(t *testing.T) {
	for _, line := range []string{"@@", "@@ -1 1 @@", "@@ -1 +x @@", "@@ -1 +1,y @@"} {
		if _, err := parseHunk(line); err == nil {
			t.Errorf("parseHunk(%q) succeeded, want error", line)
		}
	}
}

func TestKeepChanged(t *testing.T) {
	funcs := []fn{
		{name: "A", file: "a.go", startLine: 3, endLine: 8},
		{name: "B", file: "a.go", startLine: 10, endLine: 15},
		{name: "C", file: "c.go", startLine: 1, endLine: 5},
	}
	got := keepChanged(funcs, changes{"a.go": {{8, 9}}})
	if len(got) != 1 || got[0].name != "A" {
		t.Errorf("keepChanged = %v, want only A (range touches its last line)", got)
	}
	if got := keepChanged(funcs, changes{}); len(got) != 0 {
		t.Errorf("no changes should keep nothing, got %v", got)
	}
}

// TestGitChangesEndToEnd edits one of two functions in a real repository and
// checks that only the edited one survives the filter.
func TestGitChangesEndToEnd(t *testing.T) {
	if testing.Short() {
		t.Skip("runs git")
	}
	root := writeModule(t)
	git := func(args ...string) {
		t.Helper()
		cmd := exec.Command("git", append([]string{"-c", "user.name=t", "-c", "user.email=t@example.invalid",
			"-c", "commit.gpgsign=false"}, args...)...)
		cmd.Dir = root
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	git("init", "-q")
	git("add", ".")
	git("commit", "-q", "-m", "base")

	src := filepath.Join(root, "p", "p.go")
	data, err := os.ReadFile(src)
	if err != nil {
		t.Fatal(err)
	}
	edited := strings.Replace(string(data), "return 1", "return 2", 1) // inside Never
	if err := os.WriteFile(src, []byte(edited), 0o644); err != nil {
		t.Fatal(err)
	}

	ch, err := gitChanges(root, "HEAD")
	if err != nil {
		t.Fatal(err)
	}
	funcs, err := collectFuncs(root, nil)
	if err != nil {
		t.Fatal(err)
	}
	got := keepChanged(funcs, ch)
	if len(got) != 1 || got[0].name != "Never" {
		t.Fatalf("changed funcs = %v, want only Never", got)
	}
	addBase(root, "HEAD", got)
	if !got[0].hasBase || got[0].baseCC != 2 {
		t.Errorf("Never base = %+v, want existing with complexity 2", got[0])
	}
	added := []fn{{name: "Brand", file: "p/new.go"}, {name: "Fresh", file: "p/p.go"}}
	addBase(root, "HEAD", added)
	if added[0].hasBase || added[1].hasBase {
		t.Errorf("new file / new function must have no base: %+v", added)
	}
	if _, err := gitChanges(root, "no-such-rev"); err == nil {
		t.Error("unknown revision should fail")
	}
}
