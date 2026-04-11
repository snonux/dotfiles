# DTail / dserver on f3s

[DTail](https://codeberg.org/snonux/dtail) is a distributed log tool (tail/cat/grep/MapReduce) over SSH. The **dserver** daemon listens on **TCP 2222** (not port 22). Clients (`dtail`, `dcat`, `dgrep`, `dmap`, …) use normal SSH keys against dserver.

Upstream install and examples live in the repo: `doc/installation.md`, `examples/`.

## Host roles in this lab

| Hosts | OS / arch | dserver binary | Typical SSH user |
|-------|-----------|----------------|------------------|
| **pi0–pi3** | Rocky Linux 9 **aarch64** (Raspberry Pi 3) | Cross-build **linux/arm64**, `nozstd` | `paul@piN.lan.buetow.org` |
| **r0–r2** | Rocky Linux 9 **x86_64** (bhyve VMs, k3s nodes) | Cross-build **linux/amd64**, `nozstd` | Often `root@rN.lan.buetow.org` (see [Rocky Linux VMs](rocky-linux-vms.md)); add `root` (and `paul` if present) to **Server.Permissions.Users** in `dtail.json` |
| **blowfish, fishfinger** | OpenBSD 7.8 **amd64** | Native OpenBSD package build | `rex@blowfish.buetow.org`, `rex@fishfinger.buetow.org` |

**Key cache filenames matter:** `examples/update_key_cache.sh.example` only scans `/home/*` and writes `/var/run/dserver/cache/USER.authorized_keys`. In this lab, DTail auth worked only after writing the exact cache filename for the login user:

- **r0–r2**: `root.authorized_keys`
- **pi0–pi3**: `paul.authorized_keys`
- **blowfish, fishfinger**: `rex.authorized_keys`

If clients connect as **root**, copy keys once (e.g. after install) and on key changes:

```bash
cp /root/.ssh/authorized_keys /var/run/dserver/cache/root.authorized_keys
chown dserver:dserver /var/run/dserver/cache/root.authorized_keys
chmod 600 /var/run/dserver/cache/root.authorized_keys
```

For the Pi nodes:

```bash
cp /home/paul/.ssh/authorized_keys /var/run/dserver/cache/paul.authorized_keys
chown dserver:dserver /var/run/dserver/cache/paul.authorized_keys
chmod 600 /var/run/dserver/cache/paul.authorized_keys
```

## dserver on r0, r1, r2 (k3s Rocky VMs, amd64)

These hosts are the **x86_64** guests on f0/f1/f2. SSH and VM background: [Rocky Linux VMs](rocky-linux-vms.md), **DTail subsection** (same content in short form): [DTail (dserver) on r0–r2](rocky-linux-vms.md#dtail-dserver-on-r0r2). Shortcut index file: [dserver.d](dserver.d). **Do not** install the Pi **arm64** binary here.

| Item | Value |
|------|--------|
| Hostnames | `r0.lan.buetow.org`, `r1.lan.buetow.org`, `r2.lan.buetow.org` |
| LAN IPs | `192.168.1.120`–`122` |
| Admin SSH (normal) | `ssh -p 22 root@rN.lan.buetow.org` (key-based; see Rocky VM doc) |
| dserver port | **2222/tcp** (DTail clients); **22** remains sshd |

### Build the binaries (on earth)

```bash
cd ~/git/dtail   # your checkout of https://codeberg.org/snonux/dtail

# exact cross-builds for the Rocky VMs
for bin in dserver dtail dcat dgrep dmap dtailhealth; do
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -tags nozstd -o "$bin-linux-amd64" ./cmd/$bin/main.go
done
```

Use direct `go build -tags nozstd` when you need a deterministic cross-build artifact. Reusing `make dserver` after a local native build can leave an old binary in place because the target name is just `dserver`.

### Install on each rN (run as root over SSH)

1. Copy to the VM, e.g. `scp -P 22 dserver root@r0.lan.buetow.org:/tmp/` and the files from `examples/` (see checklist below), or unpack a small staging dir on `/tmp/dtail-install/`.

2. **System user and dirs**
   ```bash
   id dserver &>/dev/null || useradd -r -d /var/lib/dserver -s /sbin/nologin -U dserver
   mkdir -p /etc/dserver /var/run/dserver/cache /var/run/dserver/log
   chown -R dserver:dserver /var/run/dserver
   install -m 755 /tmp/dserver /usr/local/bin/dserver
   ```

3. **`/etc/dserver/dtail.json`** — start from `examples/dtail.json.example` and ensure **`Server.Permissions.Users` includes `"root"`** (with the same `readfiles` rules you need). The stock example lists `paul` / `pbuetow`; without **`root`**, root cannot use dserver even with a valid key.

4. **systemd units** (from repo `examples/`):
   - `dserver.service` → `/etc/systemd/system/dserver.service`
   - `update_key_cache.sh.example` → `/var/run/dserver/update_key_cache.sh` (mode `0755`)
   - `dserver-update-keycache.service` + **timer** (use a timer unit with `[Install] WantedBy=timers.target` if the raw example omits it) → `/etc/systemd/system/`
   - Optional: `prune_dserver_logs.sh.example`, `dserver-prune-logs.service`, `dserver-prune-logs.timer`

   ```bash
   systemctl daemon-reload
   systemctl enable --now dserver-update-keycache.timer
   systemctl enable --now dserver-prune-logs.timer   # if installed
   systemctl start dserver-update-keycache.service    # populate cache once
   ```

   **Important:** the stock unit uses `WorkingDirectory=/var/run/dserver`. On Rocky and Pi hosts, `dserver` failed with `status=200/CHDIR` until the unit also recreated that tmpfs path at service start. Add:

   ```ini
   RuntimeDirectory=dserver
   RuntimeDirectoryMode=0755
   ExecStartPre=/usr/bin/mkdir -p /var/run/dserver/cache /var/run/dserver/log
   ```

   Then run:

   ```bash
   systemctl daemon-reload
   systemctl reset-failed dserver
   systemctl start dserver
   ```

5. **Root SSH key cache (required on r VMs)**  
   The stock `update_key_cache.sh` only copies `/home/*/.ssh/authorized_keys`. **Root’s keys live in `/root`**, so mirror them explicitly (after any change to root’s authorized_keys):

   ```bash
   cp /root/.ssh/authorized_keys /var/run/dserver/cache/root.authorized_keys
   chown dserver:dserver /var/run/dserver/cache/root.authorized_keys
   chmod 600 /var/run/dserver/cache/root.authorized_keys
   ```

6. **firewalld** (default on Rocky):

   ```bash
   firewall-cmd --permanent --add-port=2222/tcp && firewall-cmd --reload
   ```

7. **Start dserver** (unit is **disabled** by default for boot; start manually or `enable` if desired):

   ```bash
   systemctl start dserver
   systemctl is-active dserver
   ss -tlnp | grep 2222
   ```

   Expect `dserver` listening on `*:2222` and `ssh_host_key` plus `root.authorized_keys` under `/var/run/dserver/cache/`.

### Client usage from earth

DTail uses the **same username** as normal SSH unless overridden. If dserver is set up for **root** only on r VMs, run as root or pass the client user your config expects. Example:

```bash
dcat --plain --noColor --trustAllHosts --user root \
  --servers r0.lan.buetow.org,r1.lan.buetow.org,r2.lan.buetow.org \
  --files /etc/fstab
```

Add **2222** host keys to `~/.ssh/known_hosts` the first time (interactive trust, or `ssh-keyscan -p 2222`).

## Cross-compiling dserver (from earth or any dev machine)

From a clone of the repo:

```bash
cd ~/git/dtail   # or your checkout

# Raspberry Pi 4× — linux/arm64, static, no CGO zstd
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -tags nozstd -o dserver-linux-arm64 ./cmd/dserver/main.go

# k3s VMs r0–r2 — linux/amd64
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -tags nozstd -o dserver-linux-amd64 ./cmd/dserver/main.go
```

`DTAIL_NO_ZSTD=yes` sets the `nozstd` build tag so the binary does not link DataDog’s CGO zstd (required for static cross-compiles). **`.zst` log files are not supported** in that binary; gzip still works.

## Installation checklist (each server)

Do this on **each** target (pi0–pi3 and/or r0–r2). Adjust **user** if you are not using `paul` on the node.

1. **Binary**: `/usr/local/bin/dserver`, mode `0755`, owned by root.
2. **OS user**: `dserver` system account (`useradd -r -d /var/lib/dserver -s /sbin/nologin -U dserver`).
3. **Directories**: `/etc/dserver`, `/var/run/dserver` (tmpfs — recreated at boot; use systemd `RuntimeDirectory` in the example unit if you adopt it).
4. **Config**: `/etc/dserver/dtail.json` from `examples/dtail.json.example` — ensure **Server.Permissions.Users** includes every login name that will connect (e.g. `paul`, `root`).
5. **systemd**: `examples/dserver.service.example` → `/etc/systemd/system/dserver.service` — unit stays **disabled** by default; start with `systemctl start dserver`. Add `RuntimeDirectory=dserver`, `RuntimeDirectoryMode=0755`, and `ExecStartPre=/usr/bin/mkdir -p /var/run/dserver/cache /var/run/dserver/log` so the tmpfs working directory exists before `dserver` starts.
6. **SSH host keys for clients**: dserver cannot read users’ `~/.ssh/authorized_keys` as user `dserver`. Use `examples/update_key_cache.sh.example` + `dserver-update-keycache.service` / `.timer` to mirror keys into `/var/run/dserver/cache/USER.authorized_keys`.
7. **firewalld**: allow **2222/tcp** (ping may work while TCP is blocked):

   ```bash
   sudo firewall-cmd --permanent --add-port=2222/tcp && sudo firewall-cmd --reload
   ```

   Or run `examples/firewalld-dserver-port.sh.example` once.

8. **Optional**: log pruning — `examples/prune_dserver_logs.sh.example` + `dserver-prune-logs` service/timer (see `doc/installation.md`).

## SSH from laptops (earth)

- **Port 2222** is dserver, **port 22** is normal sshd.
- If `~/.ssh/config` has a broad `Host *.buetow.org` with a wrong `Port`, **narrow overrides** for `*.lan.buetow.org` with `Port 22`, or use `ssh -p 22` / `dcat` default port 2222 only for DTail targets.
- First-time **host keys** go to `~/.ssh/known_hosts` for `[hostname]:2222` (and IP lines). A **stdout logger deadlock** when trusting new hosts was fixed upstream (release including commit `28f6319`+); rebuild clients if you still see a hang after “trust these hosts”.

## Client examples

```bash
dcat --plain --noColor --trustAllHosts --user paul \
  --servers pi0.lan.buetow.org,pi1.lan.buetow.org,pi2.lan.buetow.org,pi3.lan.buetow.org \
  --files /etc/fstab

dcat --plain --noColor --trustAllHosts --user root \
  --servers r0.lan.buetow.org,r1.lan.buetow.org,r2.lan.buetow.org \
  --files /etc/fstab
```

Use hostnames that resolve from where you run the client (often `*.lan.buetow.org`).

## Package-managed DTail

For package-repo-backed DTail and other custom package repo tasks, use the sibling `pkgrepo` skill and its reference:

- [Package Repositories](../../pkgrepo/references/package-repos.md)

That skill now owns:

- FreeBSD, OpenBSD, and Rocky client repo configuration
- custom repo layout, publication, and verification notes
- Rocky repo client configuration and RPM install flow
- OpenBSD DTail package build, publish, replace, and cache-refresh steps
- DTail package publication details that depend on the repo

## Verified lab state

On 2026-04-11 this setup was verified end-to-end with:

- the full Linux binary set (`dserver`, `dtail`, `dcat`, `dgrep`, `dmap`, `dtailhealth`) installed on `r0`-`r2` and `pi0`-`pi3`
- `dserver` active and listening on `*:2222` on all seven hosts
- successful `dcat /etc/fstab` reads from earth using `--user root` for `r0`-`r2` and `--user paul` for `pi0`-`pi3`

## k3s / r0–r2 notes

- **amd64** binaries only; do not deploy the Pi **arm64** build there.
- Same **2222** and **firewalld** rules apply.
- These VMs are heavier than the Pis; defaults in `dtail.json` (`MaxConcurrentCats`, etc.) can be raised if needed.
- Full install sequence for these three nodes: section **dserver on r0, r1, r2** above.

## Related upstream fixes (f3s-relevant)

- **Host key file**: first boot uses `RootedPath.Stat` + `errors.Is(…, fs.ErrNotExist)` so missing `cache/ssh_host_key` triggers generation (older `os.IsNotExist` missed wrapped errors).
- **Known-hosts prompt deadlock**: `internal/io/dlog/loggers/stdout.go` must not hold its mutex across the pause/resume wait when the trust prompt runs.
