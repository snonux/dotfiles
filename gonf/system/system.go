package system

import (
	"path/filepath"
	"strings"

	"github.com/snonux/dotfiles/gonf/fleet"
	. "github.com/snonux/gonf/api"
)

// System contains root-owned configuration of the Fedora laptop earth
// outside the package database. main.go registers it with a hostname guard,
// so it never applies to another host this module is pushed to.
type System struct {
	RequiresRoot
}

const (
	etcHosts     = "/etc/hosts"
	wireGuardDir = "/etc/wireguard"
)

// wireGuardConfigs are the tunnel configs gonf keeps private. Their content
// has other owners: wg0.conf is rendered and installed by
// ~/git/wireguardmeshgenerator (run it through conf's by-name task
// wireguard_mesh_install), wg1.conf is replaced (and extended with peers) by
// the hyperstack tooling's wg1-setup.sh on every VM create.
var wireGuardConfigs = List(wireGuardDir+"/wg0.conf", wireGuardDir+"/wg1.conf")

func (System) DescHosts() string { return "Manage the fleet block of /etc/hosts (earth)" }

// Hosts owns only the "# BEGIN GONF fleet" block of /etc/hosts: the LAN and
// wg0 mesh rows from the fleet package. Everything outside the markers stays
// as it is: Fedora's stock loopback header, and the hyperstack*.wg1 rows that
// wg1-setup.sh deletes and re-appends with sed/tee on every VM create (its
// sed only matches lines ending in the VM's own wg1 name, never a fleet row).
// Mode 0644 root:root is Fedora's stock for the file; before gonf it had
// drifted to 0664 root:wheel.
func (System) Hosts() {
	File(etcHosts, WithBlock("fleet", fleet.EarthHostsBlock()...), Perm(0o644, Root))
}

func (System) DescWireguard() string {
	return "Keep /etc/wireguard and the wg0/wg1 configs private (earth, perms only)"
}

// Wireguard (task system_wireguard) manages permissions only, never
// content or units: the directory is 0700 root:root and each existing tunnel
// config 0600 root:root, since they hold private keys. A config that does not exist
// (no hyperstack VM yet) is not created.
//
// wg-quick@wg0 and wg-quick@wg1 are enabled for auto-start at boot (user
// decision 2026-09-25) for each tunnel whose config exists. Enable only, via
// a guarded systemctl call: gonf's Service would also start them, and a
// deploy must never bring a tunnel up or down on this roaming laptop.
//
// The directory also holds files neither generator writes (dated backups,
// the single-gateway variants wg0-blowfish.conf and wg0-fishfinger.conf).
// They are 0600 already and are left alone: deleting them is the user's
// decision.
func (System) Wireguard() {
	Dir(wireGuardDir, Perm(0o700, Root))
	for _, conf := range wireGuardConfigs {
		WhenPathExists(conf, func() {
			EnsureFile(conf, Perm(0o600, Root))
			unit := "wg-quick@" + strings.TrimSuffix(filepath.Base(conf), ".conf")
			Command("systemctl", List("enable", unit),
				OnlyIf("sh", List("-c", "! systemctl is-enabled --quiet "+unit)))
		})
	}
}
