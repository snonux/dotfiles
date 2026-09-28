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

	home, err := api.RecordPlanTo("home-test", plan.NewMemoryStore(), "home")
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
