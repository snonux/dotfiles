# shellcheck shell=bash
# Canonical f3s fleet inventory for ops scripts under scripts/.
#
# Source this file; do not execute it. Facts (IPs, MACs, role hostnames,
# DNS order) live here so wol-f3s, pihole-dns-toggle, home-backup, and
# temp-backup do not drift independently.
#
# Immich base URLs are recorded for inventory completeness; sibling
# immich-* workers are out of scope for the u33 wiring pass.
#
# SC2034: names are the public API for sourcing consumers; unused-here
# warnings are expected when shellcheck scans this file alone.
# shellcheck disable=SC2034

[[ "${_F3S_HOSTS_SOURCED:-no}" == yes ]] && return 0
_F3S_HOSTS_SOURCED=yes

# --- LAN addressing ---
declare -gr F3S_LAN_BROADCAST='192.168.1.255'
declare -gr F3S_LAN_GATEWAY='192.168.1.1'
# Intermediate DNS fallback before the LAN gateway (client nmcli order).
declare -gr F3S_DNS_FALLBACK='192.168.1.101'
declare -gr F3S_CARP_VIP='192.168.1.138'

# --- Identity / roles ---
declare -gr F3S_SSH_USER='paul'
# home-backup default remote host (encrypted ZFS on f2).
declare -gr F3S_HOME_BACKUP_HOST='f2.lan'
# temp-backup default remote host (WireGuard name for f0).
declare -gr F3S_TEMP_BACKUP_HOST='f0.wg0'
# Rack-fan Shelly Plug (HTTP RPC).
declare -gr F3S_SHELLY_IP='192.168.1.28'

# Immich ingress (inventory only; consumers may opt in later).
declare -gr F3S_IMMICH_LAN_URL='http://immich.f3s.lan.buetow.org'
declare -gr F3S_IMMICH_PUBLIC_URL='https://immich.f3s.buetow.org'

# Gogios mute gateways (OpenBSD frontends).
declare -gra F3S_GOGIOS_GATEWAYS=(
    blowfish.buetow.org
    fishfinger.buetow.org
)

# Role groups (ordered).
declare -gra F3S_BEELINKS=(f0 f1 f2 f3)
# Default WoL/shutdown set excludes f3 (standalone, not k3s).
declare -gra F3S_BEELINKS_DEFAULT=(f0 f1 f2)
declare -gra F3S_PIS=(pi0 pi1 pi2 pi3)
declare -gra F3S_K3S_NODES=(r0 r1 r2)

# Host → LAN IP
declare -gA F3S_HOST_IP=(
    [f0]=192.168.1.130
    [f1]=192.168.1.131
    [f2]=192.168.1.132
    [f3]=192.168.1.133
    [r0]=192.168.1.120
    [r1]=192.168.1.121
    [r2]=192.168.1.122
    [pi0]=192.168.1.125
    [pi1]=192.168.1.126
    [pi2]=192.168.1.127
    [pi3]=192.168.1.128
)

# Host → WoL MAC (Beelinks only; Pis have no WoL).
declare -gA F3S_HOST_MAC=(
    [f0]=e8:ff:1e:d7:1c:ac
    [f1]=e8:ff:1e:d7:1e:44
    [f2]=e8:ff:1e:d7:1c:a0
    [f3]=e8:ff:1e:d7:f3:d7
)

# Pi-hole client DNS order: pi2, pi3, intermediate fallback, gateway.
declare -gr F3S_PIHOLE_DNS="${F3S_HOST_IP[pi2]} ${F3S_HOST_IP[pi3]} ${F3S_DNS_FALLBACK} ${F3S_LAN_GATEWAY}"

# f3s_host_ip NAME — print LAN IP for a known host role, or return 1.
f3s_host_ip() {
    local -r name="$1"
    local ip="${F3S_HOST_IP[$name]:-}"
    [[ -n "$ip" ]] || return 1
    printf '%s\n' "$ip"
}

# f3s_host_mac NAME — print WoL MAC for a Beelink role, or return 1.
f3s_host_mac() {
    local -r name="$1"
    local mac="${F3S_HOST_MAC[$name]:-}"
    [[ -n "$mac" ]] || return 1
    printf '%s\n' "$mac"
}
