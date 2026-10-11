package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/snonux/gonf/api"
	"github.com/snonux/gonf/cli"
	"github.com/snonux/gonf/plan"
	"github.com/snonux/gonf/resource"
)

// The child starts with the checkout root and an isolated HOME set before
// paths package initialization, so plan recording is independent of the
// developer's dotfiles and optional private checkouts.
func TestHomeAndUploadPlans(t *testing.T) {
	if os.Getenv("GONF_TEST_HOME_PLAN") == "1" {
		checkHomeAndUploadPlans(t)
		return
	}
	output, err := runIsolated(t, "TestHomeAndUploadPlans", "GONF_TEST_HOME_PLAN=1")
	if err != nil {
		t.Fatalf("plan assertions failed: %v\n%s", err, output)
	}
}

func TestHomeCLIPrivilege(t *testing.T) {
	if task := os.Getenv("GONF_TEST_CLI_TASK"); task != "" {
		if task == "privilege_probe" {
			// An unguarded root operation exercises the same CLI preflight
			// on hosts outside earth/zen. Drop root in this child when the
			// test suite itself is running as root.
			api.Task(task, "privilege preflight probe", func() { api.Package("uptimed") }, api.Privileged())
			if os.Geteuid() == 0 {
				if err := syscall.Setuid(65534); err != nil {
					t.Fatal(err)
				}
			}
		} else {
			registerTasks()
		}
		os.Args = []string{"gonf", "-n", task}
		os.Exit(cli.CLI())
	}

	output, err := runIsolated(t, "TestHomeCLIPrivilege", "GONF_TEST_CLI_TASK=home")
	if err != nil {
		t.Fatalf("gonf -n home failed: %v\n%s", err, output)
	}

	output, err = runIsolated(t, "TestHomeCLIPrivilege", "GONF_TEST_CLI_TASK=privilege_probe")
	if err == nil || !strings.Contains(string(output), "privilege mode is none") || !strings.Contains(string(output), "Package[uptimed]") {
		t.Fatalf("gonf -n privilege_probe: error = %v, output = %q; want privilege preflight failure for uptimed", err, output)
	}
}

func runIsolated(t *testing.T, testName string, extraEnv ...string) ([]byte, error) {
	t.Helper()
	root, err := filepath.Abs("../../..")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=^"+testName+"$")
	cmd.Env = append(append(os.Environ(), extraEnv...),
		"GONF_DOTFILES_ROOT="+root,
		"HOME="+t.TempDir(),
	)
	return cmd.CombinedOutput()
}

func checkHomeAndUploadPlans(t *testing.T) {
	registerTasks()

	store := plan.NewMemoryStore()
	home, err := api.RecordPlanTo("home-test", store, "home")
	if err != nil {
		t.Fatal(err)
	}
	// The aggregate must contain every registered home task except the
	// explicitly separate upload task and compatibility aliases.
	var members []string
	for _, task := range api.Tasks() {
		if strings.HasPrefix(task.Name, "home_") && task.AliasOf == "" && task.Name != "home_goprecords_upload" {
			members = append(members, task.Name)
		}
	}
	expected, err := api.RecordPlanTo("home-test", plan.NewMemoryStore(), members...)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(home, expected) {
		t.Error("home aggregate does not match the registered unprivileged home tasks")
	}
	for _, op := range home {
		if op.Elevate {
			t.Errorf("home contains privileged op %s", op.ID)
		}
		if strings.Contains(op.ID, "goprecords-upload-earth") || strings.Contains(op.ID, "goprecords-upload-zen") {
			t.Errorf("home contains upload op %s", op.ID)
		}
	}
	for _, suffix := range []string{"/.bashrc", "/.ssh/config", "/.config/tmux"} {
		if !hasPlanPath(home, suffix) {
			t.Errorf("home omits unprivileged resource ending %s", suffix)
		}
	}

	checkScriptsPlan(t, home, store)
	checkSystemPlans(t)

	upload, err := api.RecordPlanTo("upload-test", plan.NewMemoryStore(), "home_goprecords_upload")
	if err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{"Package[uptimed]", "Service[uptimed]"} {
		if !hasElevatedID(upload, id) {
			t.Errorf("upload omits privileged prerequisite %s", id)
		}
	}
	if !hasPlanPath(upload, "/.local/bin/goprecords-upload-client.sh") {
		t.Error("upload omits its unprivileged client")
	}
}

func hasPlanPath(ops []plan.Op, suffix string) bool {
	for _, op := range ops {
		if strings.HasSuffix(op.Path, suffix) {
			return true
		}
	}
	return false
}

func hasElevatedID(ops []plan.Op, id string) bool {
	for _, op := range ops {
		if op.ID == id && op.Elevate {
			return true
		}
	}
	return false
}

// checkScriptsPlan pins packaged production files without applying to the host.
func checkScriptsPlan(t *testing.T, ops []plan.Op, store *plan.MemoryStore) {
	t.Helper()
	for _, op := range ops {
		if op.ID != "Directory[${HOME}/scripts]" {
			continue
		}
		payload := plan.PayloadOf[plan.SyncDirPayload](op)
		if op.Op != plan.KindSyncDir || op.Mode != "0700" || payload.FileMode != "0750" || payload.Glob || !op.Prune {
			t.Fatalf("scripts tree attributes: %+v, %+v", op, payload)
		}
		if !reflect.DeepEqual(payload.Exclude, []string{"tests", "quicklog", "quicklog-drain-e2e"}) {
			t.Fatalf("scripts exclusions: %v", payload.Exclude)
		}
		entries, ok := store.TreeBlob(op.Blob)
		if !ok {
			t.Fatal("missing scripts tree blob")
		}
		found := map[string]bool{}
		for _, entry := range entries {
			found[entry.Rel] = true
			if entry.Rel == "tests" || strings.HasPrefix(entry.Rel, "tests/") || entry.Rel == "quicklog" || strings.HasPrefix(entry.Rel, "quicklog/") || entry.Rel == "quicklog-drain-e2e" {
				t.Errorf("repo-only script entered blob: %s", entry.Rel)
			}
		}
		for _, name := range []string{"quicklog-drain", "taskwarrior-export-e2e", "lib/f3s-hosts.sh", "lib/immich.sh", "lib/e2e-assert.sh"} {
			if !found[name] {
				t.Errorf("scripts blob omits %s", name)
			}
		}
		for _, member := range ops {
			if member.ID == "Directory[${HOME}/scripts/quicklog]" && member.Mode == "0750" && reflect.DeepEqual(member.Deps, []string{op.ID}) {
				checkQuicklogTree(t, member, store)
				checkScriptsConvergence(t)
				return
			}
		}
		t.Fatal("quicklog tree must own its 0750 mode and depend on main sync")
	}
	t.Fatal("home omits scripts tree")
}

func checkSystemPlans(t *testing.T) {
	t.Helper()
	ops, err := api.RecordPlanTo("system-test", plan.NewMemoryStore(), "system_wireguard", "system_fish_shell")
	if err != nil {
		t.Fatal(err)
	}
	services := 0
	user := false
	guard := ""
	for _, op := range ops {
		if op.Op == plan.KindWhenBegin && strings.HasPrefix(op.ID, "when.path_exists:") {
			guard = strings.TrimPrefix(op.ID, "when.path_exists:")
		}
		if op.Op == plan.KindWhenEnd {
			guard = ""
		}
		if op.Op == plan.KindCommand {
			t.Errorf("system task still shells out: %s", op.ID)
		}
		if op.Op == plan.KindService {
			services++
			conf := "/etc/wireguard/" + strings.TrimPrefix(op.Name, "wg-quick@") + ".conf"
			if !op.EnableOnly || !op.Elevate || guard != conf || op.Restart || op.Reload {
				t.Errorf("tunnel service escaped enable-only config guard: %+v, guard %s", op, guard)
			}
		}
		if op.ID == "User[paul]" {
			user = true
			want := plan.UserPayload{Shell: "/usr/bin/fish", ManageShell: true}
			if !reflect.DeepEqual(plan.PayloadOf[plan.UserPayload](op), want) || !op.Elevate || !reflect.DeepEqual(op.Deps, []string{"Package[fish]"}) {
				t.Errorf("fish changes more than shell or lacks package dependency: %+v", op)
			}
		}
	}
	if services != 2 || !user {
		t.Errorf("system plans: services=%d, user=%t", services, user)
	}
}

func checkQuicklogTree(t *testing.T, op plan.Op, store *plan.MemoryStore) {
	t.Helper()
	payload := plan.PayloadOf[plan.SyncDirPayload](op)
	if op.Op != plan.KindSyncDir || !op.Prune || payload.FileMode != "0750" || !reflect.DeepEqual(payload.Exclude, []string{"e2e"}) {
		t.Fatalf("quicklog tree attributes: %+v, %+v", op, payload)
	}
	entries, ok := store.TreeBlob(op.Blob)
	if !ok || len(entries) != 1 || entries[0].Rel != "drain" {
		t.Fatalf("quicklog tree must package only drain: %+v", entries)
	}
}

// checkScriptsConvergence applies only scripts into this child's isolated HOME.
func checkScriptsConvergence(t *testing.T) {
	t.Helper()
	dst := filepath.Join(os.Getenv("HOME"), "scripts")
	for _, name := range []string{"tests/local-note", "quicklog/e2e/local-note", "quicklog-drain-e2e", "stale", "quicklog/stale"} {
		path := filepath.Join(dst, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte("unmanaged"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	planDir := t.TempDir()
	ops, err := api.RecordPlan("scripts-test", planDir, "home_scripts")
	if err != nil {
		t.Fatal(err)
	}
	for run := 0; run < 2; run++ {
		if err := plan.Apply(ops, plan.Facts{GOOS: "linux"}, planDir); err != nil {
			t.Fatal(err)
		}
		for _, name := range []string{"tests/local-note", "quicklog/e2e/local-note"} {
			data, err := os.ReadFile(filepath.Join(dst, name))
			if err != nil || string(data) != "unmanaged" {
				t.Fatalf("excluded %s changed: %q, %v", name, data, err)
			}
		}
		for _, name := range []string{"quicklog-drain-e2e", "stale", "quicklog/stale"} {
			if _, err := os.Stat(filepath.Join(dst, name)); !os.IsNotExist(err) {
				t.Fatalf("%s was not removed: %v", name, err)
			}
		}
		for name, mode := range map[string]os.FileMode{".": 0o700, "quicklog": 0o750, "quicklog/drain": 0o750, "lib/f3s-hosts.sh": 0o750, "tests/local-note": 0o600, "quicklog/e2e/local-note": 0o600} {
			info, err := os.Stat(filepath.Join(dst, name))
			if err != nil || info.Mode().Perm() != mode {
				t.Fatalf("%s mode: want %o, info %v, error %v", name, mode, info, err)
			}
		}
		if run == 1 && resource.AnyChanged("Directory["+dst+"]", "Directory["+dst+"/quicklog]", "File["+dst+"/quicklog-drain-e2e]") {
			t.Fatal("second scripts apply changed an already converged destination")
		}
	}
}
