package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/snonux/gonf/api"
	"github.com/snonux/gonf/plan"
	"github.com/snonux/gonf/resource"
)

// Apply the recorded files in an isolated HOME: this checks destination guards,
// bootstrap without credentials, preservation of a local password, and convergence.
// The real systemd/IMAP/SMTP path is exercised separately on earth.
func TestAercDeployment(t *testing.T) {
	if os.Getenv("GONF_TEST_AERC") != "1" {
		output, err := runIsolated(t, "TestAercDeployment", "GONF_TEST_AERC=1")
		if err != nil {
			t.Fatalf("aerc deployment failed: %v\n%s", err, output)
		}
		return
	}
	registerTasks()
	planDir := t.TempDir()
	ops, err := api.RecordPlan("aerc-test", planDir, "home_aerc")
	if err != nil {
		t.Fatal(err)
	}
	var files []plan.Op
	service := false
	for _, op := range ops {
		if op.Elevate || op.Op == plan.KindCommand {
			t.Fatalf("aerc requires privilege or shells out: %s", op.ID)
		}
		if op.Op == plan.KindService {
			service = true
			if op.Name != "protonbridge-k3s-tunnel" || !op.User || !op.Restart || !op.IfChanged || len(op.Watch) != 1 {
				t.Fatalf("tunnel must converge on user bus and restart on unit changes: %+v", op)
			}
		}
		if op.Op != plan.KindService && op.Op != plan.KindDaemonReload {
			files = append(files, op)
		}
	}
	if !service {
		t.Fatal("aerc omits tunnel activation")
	}
	dst := filepath.Join(os.Getenv("HOME"), ".config/aerc")
	for _, facts := range []plan.Facts{{GOOS: "linux", Hostname: "zen"}, {GOOS: "darwin", Hostname: "earth"}} {
		if err := plan.Apply(files, facts, planDir); err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(dst); !os.IsNotExist(err) {
			t.Fatalf("aerc applied on %+v: %v", facts, err)
		}
	}
	earth := plan.Facts{GOOS: "linux", Hostname: "earth"}
	if err := plan.Apply(files, earth, planDir); err != nil {
		t.Fatal(err)
	}
	password := filepath.Join(dst, "protonbridge-password")
	if _, err := os.Stat(password); !os.IsNotExist(err) {
		t.Fatalf("bootstrap must leave missing credentials absent: %v", err)
	}
	const secret = "test-only-local-credential\n"
	if err := os.WriteFile(password, []byte(secret), 0o644); err != nil {
		t.Fatal(err)
	}
	for run := 0; run < 2; run++ {
		if err := plan.Apply(files, earth, planDir); err != nil {
			t.Fatal(err)
		}
		data, err := os.ReadFile(password)
		if err != nil || string(data) != secret {
			t.Fatal("aerc changed the local credential")
		}
		for rel, mode := range map[string]os.FileMode{
			".config/aerc":                            0o700,
			".config/aerc/accounts.conf":              0o600,
			".config/aerc/protonbridge-password":      0o600,
			".config/aerc/protonbridge-ca-bundle.pem": 0o644,
			".protonbridge":                           0o600,
			"bin/aerc":                                0o755,
		} {
			info, err := os.Stat(filepath.Join(os.Getenv("HOME"), rel))
			if err != nil || info.Mode().Perm() != mode {
				t.Fatalf("%s mode: want %o, info %v, error %v", rel, mode, info, err)
			}
		}
		if run == 1 {
			for _, op := range files {
				if op.Path != "" && resource.AnyChanged(op.ID) {
					t.Errorf("second apply changed %s", op.ID)
				}
			}
		}
	}
}
