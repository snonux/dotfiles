// Package fleet is the homelab host inventory the laptop earth resolves
// through /etc/hosts: the LAN names (192.168.1.0/24) and the wg0 mesh names
// (192.168.2.0/24, fd42:beef:cafe:2::/64).
//
// Source of truth. The rows are a copy, kept in the same order and row
// format, of ~/git/conf/gonf/etchosts/etchosts.go (lanHosts) and
// ~/git/conf/gonf/frontends/data.go (wireGuardAddresses, plus etchosts'
// wireGuardExtras), which render /etc/hosts on the f-hosts and r-nodes. The
// wg0 addresses themselves come from ~/git/wireguardmeshgenerator
// (wireguardmeshgenerator.yaml), the owner of the mesh. conf is not
// imported as a Go module: this module is pushed to hosts without a conf
// checkout (rocky, a Mac), and conf is not versioned for import. Change a
// shared row there first, then here.
//
// earthLAN and earthWireGuard are the rows only the laptop needs.
package fleet

// lanHost is one LAN row: "IP name name.lan name.lan.buetow.org aliases...".
type lanHost struct {
	name    string
	ip      string
	aliases []string
}

// wireGuardPeer is one wg0 mesh member with both of its addresses.
type wireGuardPeer struct {
	name string
	ipv4 string
	ipv6 string
}

// lanHosts mirrors conf's etchosts.lanHosts: hypervisors, the CARP storage
// VIP, the k3s VMs and the plain rocky VM, then the Pis (the old t450 laptop was retired on 2026-09-25).
var lanHosts = []lanHost{
	{name: "f0", ip: "192.168.1.130"},
	{name: "f1", ip: "192.168.1.131"},
	{name: "f2", ip: "192.168.1.132"},
	{name: "f3", ip: "192.168.1.133"},
	{name: "f3s-storage-ha", ip: "192.168.1.138"},
	{name: "r0", ip: "192.168.1.120"},
	{name: "r1", ip: "192.168.1.121"},
	{name: "r2", ip: "192.168.1.122"},
	{name: "rocky", ip: "192.168.1.123"},
	{name: "pi0", ip: "192.168.1.125"},
	{name: "pi1", ip: "192.168.1.126"},
	{name: "pi2", ip: "192.168.1.127"},
	{name: "pi3", ip: "192.168.1.128"},
}

// earthLAN are LAN rows beyond conf's inventory: the two Shelly plugs and
// the stopped-by-default freebsd development VM on f3 (its backup-restore
// test clone reuses the same address), with its old "fbsd" alias.
var earthLAN = []lanHost{
	{name: "shelly1", ip: "192.168.1.28"},
	{name: "shelly2", ip: "192.168.1.29"},
	{name: "freebsd", ip: "192.168.1.139", aliases: []string{"fbsd"}},
}

// wireGuardPeers mirrors conf's frontends.wireGuardAddresses followed by
// etchosts.wireGuardExtras (f3).
var wireGuardPeers = []wireGuardPeer{
	{name: "blowfish", ipv4: "192.168.2.110", ipv6: "fd42:beef:cafe:2::110"},
	{name: "fishfinger", ipv4: "192.168.2.111", ipv6: "fd42:beef:cafe:2::111"},
	{name: "r0", ipv4: "192.168.2.120", ipv6: "fd42:beef:cafe:2::120"},
	{name: "r1", ipv4: "192.168.2.121", ipv6: "fd42:beef:cafe:2::121"},
	{name: "r2", ipv4: "192.168.2.122", ipv6: "fd42:beef:cafe:2::122"},
	{name: "rocky", ipv4: "192.168.2.123", ipv6: "fd42:beef:cafe:2::123"},
	{name: "f0", ipv4: "192.168.2.130", ipv6: "fd42:beef:cafe:2::130"},
	{name: "f1", ipv4: "192.168.2.131", ipv6: "fd42:beef:cafe:2::131"},
	{name: "f2", ipv4: "192.168.2.132", ipv6: "fd42:beef:cafe:2::132"},
	{name: "pi0", ipv4: "192.168.2.203", ipv6: "fd42:beef:cafe:2::203"},
	{name: "pi1", ipv4: "192.168.2.204", ipv6: "fd42:beef:cafe:2::204"},
	{name: "earth", ipv4: "192.168.2.200", ipv6: "fd42:beef:cafe:2::200"},
	{name: "pixel7pro", ipv4: "192.168.2.201", ipv6: "fd42:beef:cafe:2::201"},
	{name: "f3", ipv4: "192.168.2.133", ipv6: "fd42:beef:cafe:2::133"},
}

// earthWireGuard are mesh members of wireguardmeshgenerator.yaml that conf's
// hosts do not resolve: the freebsd VM and uranus.
var earthWireGuard = []wireGuardPeer{
	{name: "freebsd", ipv4: "192.168.2.202", ipv6: "fd42:beef:cafe:2::202"},
	{name: "uranus", ipv4: "192.168.2.205", ipv6: "fd42:beef:cafe:2::205"},
}

// EarthHostsBlock returns the /etc/hosts block of the laptop earth: a
// comment, the LAN rows, a comment, then the wg0 rows (all IPv4, then all
// IPv6, like conf's frontends.WireGuardHostLines).
func EarthHostsBlock() []string {
	lan := append(append([]lanHost(nil), lanHosts...), earthLAN...)
	wg := append(append([]wireGuardPeer(nil), wireGuardPeers...), earthWireGuard...)
	lines := make([]string, 0, 2+len(lan)+2*len(wg))
	lines = append(lines, "# LAN (192.168.1.0/24)")
	lines = append(lines, lanLines(lan)...)
	lines = append(lines, "# WireGuard mesh wg0 (wireguardmeshgenerator)")
	return append(lines, wireGuardLines(wg)...)
}

// lanLines renders LAN rows: "IP name name.lan name.lan.buetow.org aliases...".
func lanLines(hosts []lanHost) []string {
	lines := make([]string, 0, len(hosts))
	for _, h := range hosts {
		line := h.ip + " " + h.name + " " + h.name + ".lan " + h.name + ".lan.buetow.org"
		for _, alias := range h.aliases {
			line += " " + alias
		}
		lines = append(lines, line)
	}
	return lines
}

// wireGuardLines renders wg0 rows, "IP name.wg0.wan.buetow.org name.wg0",
// all IPv4 rows first, then all IPv6 rows.
func wireGuardLines(peers []wireGuardPeer) []string {
	lines := make([]string, 0, 2*len(peers))
	for _, p := range peers {
		lines = append(lines, p.ipv4+" "+p.name+".wg0.wan.buetow.org "+p.name+".wg0")
	}
	for _, p := range peers {
		lines = append(lines, p.ipv6+" "+p.name+".wg0.wan.buetow.org "+p.name+".wg0")
	}
	return lines
}
