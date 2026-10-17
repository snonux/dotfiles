package home

import (
	"github.com/snonux/dotfiles/gonf/paths"
	. "github.com/snonux/gonf/api"
)

func (HomeTasks) OptsAerc() TaskOptions {
	return TaskOptions{WhenLinux(), WhenHostnameContains("earth")}
}

// Aerc installs aerc's connection to Proton Bridge in k3s (Linux, earth).
//
// The password is provisioned separately from Bridge's info command. Only
// its permissions are managed here; its bytes never enter a recorded plan.
func (HomeTasks) Aerc() {
	Dir(DestHome(".config/aerc"), WithMode(0o700))
	InstallFile(DestHome(".config/aerc/accounts.conf"), paths.Dot("aerc/accounts.conf"), WithMode(0o600))
	InstallFile(DestHome(".config/aerc/protonbridge-ca-bundle.pem"), paths.Dot("aerc/protonbridge-ca-bundle.pem"), WithMode(0o644))
	InstallFile(DestHome(".protonbridge"), paths.Dot("aerc/protonbridge.env"), WithMode(0o600))

	EnsureDir(DestHome("bin"), WithMode(0o755))
	InstallFile(DestHome("bin/aerc"), paths.Dot("aerc/aerc"), WithMode(0o755))
	EnsureDir(DestHome(".config/autostart"), WithMode(0o755))
	InstallFile(DestHome(".config/autostart/Proton Mail Bridge.desktop"),
		paths.Dot("aerc/Proton Mail Bridge.desktop"), WithMode(0o644))

	EnsureDir(DestHome(".config/systemd/user"), WithMode(0o750))
	unit := InstallFile(DestHome(".config/systemd/user/protonbridge-k3s-tunnel.service"),
		paths.Dot("systemd-user/protonbridge-k3s-tunnel.service"), WithMode(0o644))
	SystemdUnits(WithUserBus(), FanIn(unit),
		ActivateService("protonbridge-k3s-tunnel", WithRestart))

	// Do not create a misleading empty credential file on a fresh laptop.
	WhenPathExists(DestHome(".config/aerc/protonbridge-password"), func() {
		EnsureFile(DestHome(".config/aerc/protonbridge-password"), WithMode(0o600))
	})
}
