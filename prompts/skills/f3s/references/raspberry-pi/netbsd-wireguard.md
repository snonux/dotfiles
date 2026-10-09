# NetBSD Pis: WireGuard (userspace)

## WireGuard (userspace deployment; 10.1 module finding retained as evidence)

**Historical 10.1 finding:** `wg(4)` did not exist in the evbarm-aarch64 10.1 module set — the module was absent from
all 249 files under `/stand/evbarm/10.1/modules`, so `ifconfig wg0 create`
fails outright (`clone_command: Invalid argument`), despite `wg(4)` being
upstream NetBSD since 9.2. Don't waste time on it; `wireguard-go` + `wg`
(pkgsrc `wireguard-tools`, **no `wg-quick`** in this build) is the working
path:

```sh
pkgin -y install wireguard-go wireguard-tools
```

**`wireguardmeshgenerator` (`~/git/wireguardmeshgenerator`) has full NetBSD
support** — for a host with `os: NetBSD` in `wireguardmeshgenerator.yaml`,
`--generate` produces both the stripped `tun0.conf` (no `Address`/`DNS` lines
— `wg setconf` rejects wg-quick extensions with "Line unrecognized") and the
`/etc/rc.d/wireguard` script itself, with one `route add`/`delete` pair per
peer AllowedIPs prefix (wg-quick would normally manage these automatically;
`wg` only does the crypto/routing decision inside the tunnel). `--install`
uploads and places both files with the right ownership/permissions and
restarts the service. Per-host YAML fields that matter for a NetBSD entry:

```yaml
pi0:
  os: NetBSD
  ssh:
    user: paul
    conf_dir: /usr/pkg/etc/wireguard
    sudo_cmd: doas
    reload_cmd: /etc/rc.d/wireguard restart
    wg_bin: /usr/pkg/bin/wg   # doas's PATH excludes /usr/pkg/bin
```

Key facts the generator's implementation encodes:

- The interface **must** be named `tunN` (`wireguard-go` rejects `wg0`:
  "Interface name must be tun[0-9]*"). The generator always uses `tun0`.
- **The interface must be addressed before `wireguard-go` starts**, or its
  read loop dies immediately with `EHOSTDOWN` ("host is down") and does not
  retry — the generated rc.d script's `wireguard_start` does `ifconfig`
  before `wireguard-go`.
- `doas` on NetBSD resets `PATH` to exclude both `/usr/pkg/bin` (hence the
  `wg_bin` override above) and `/usr/sbin` (hence the generator using a full
  path for `chown` during install — caught by actually running `--install`
  against a live host, not by inspection).

To (re)deploy after any topology change: `ruby wireguardmeshgenerator.rb
--generate --install --hosts=pi0,pi1`.
