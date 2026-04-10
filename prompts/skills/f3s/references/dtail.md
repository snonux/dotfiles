# DTail / dserver on f3s

[DTail](https://codeberg.org/snonux/dtail) is a distributed log tool (tail/cat/grep/MapReduce) over SSH. The **dserver** daemon listens on **TCP 2222** (not port 22). Clients (`dtail`, `dcat`, `dgrep`, `dmap`, …) use normal SSH keys against dserver.

Upstream install and examples live in the repo: `doc/installation.md`, `examples/`.

## Host roles in this lab

| Hosts | OS / arch | dserver binary | Typical SSH user |
|-------|-----------|----------------|------------------|
| **pi0–pi3** | Rocky Linux 9 **aarch64** (Raspberry Pi 3) | Cross-build **linux/arm64**, `nozstd` | `paul@piN.lan.buetow.org` |
| **r0–r2** | Rocky Linux 9 **x86_64** (bhyve VMs, k3s nodes) | Cross-build **linux/amd64**, `nozstd` | Often `root@rN.lan.buetow.org` (see [Rocky Linux VMs](rocky-linux-vms.md)); add `root` (and `paul` if present) to **Server.Permissions.Users** in `dtail.json` |

**Root login and key cache:** `examples/update_key_cache.sh.example` only scans `/home/*`. If clients connect as **root**, copy keys once (e.g. after install) and on key changes:

```bash
cp /root/.ssh/authorized_keys /var/run/dserver/cache/root.authorized_keys
chown dserver:dserver /var/run/dserver/cache/root.authorized_keys
chmod 600 /var/run/dserver/cache/root.authorized_keys
```

## dserver on r0, r1, r2 (k3s Rocky VMs, amd64)

These hosts are the **x86_64** guests on f0/f1/f2. SSH and VM background: [Rocky Linux VMs](rocky-linux-vms.md), **DTail subsection** (same content in short form): [DTail (dserver) on r0–r2](rocky-linux-vms.md#dtail-dserver-on-r0r2). Shortcut index file: [dserver.d](dserver.d). **Do not** install the Pi **arm64** binary here.

| Item | Value |
|------|--------|
| Hostnames | `r0.lan.buetow.org`, `r1.lan.buetow.org`, `r2.lan.buetow.org` |
| LAN IPs | `192.168.1.120`–`122` |
| Admin SSH (normal) | `ssh -p 22 root@rN.lan.buetow.org` (key-based; see Rocky VM doc) |
| dserver port | **2222/tcp** (DTail clients); **22** remains sshd |

### Build the binary (on earth)

```bash
cd ~/git/dtail   # your checkout of https://codeberg.org/snonux/dtail
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 DTAIL_NO_ZSTD=yes make dserver
# artifact: ./dserver  (static amd64; copy as e.g. dserver-linux-amd64)
```

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
dcat --servers r0.lan,r1.lan,r2.lan /etc/hostname
# if your client user must be root for key + dtail.json to match:
# sudo dcat ...   # or configure SSH user flags if the client supports them
```

Add **2222** host keys to `~/.ssh/known_hosts` the first time (interactive trust, or `ssh-keyscan -p 2222`).

## Cross-compiling dserver (from earth or any dev machine)

From a clone of the repo:

```bash
cd ~/git/dtail   # or your checkout

# Raspberry Pi 4× — linux/arm64, static, no CGO zstd
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 DTAIL_NO_ZSTD=yes make dserver
# produces ./dserver — keep a copy e.g. ./dserver-linux-arm64

# k3s VMs r0–r2 — linux/amd64
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 DTAIL_NO_ZSTD=yes make dserver
# produces ./dserver — keep a copy e.g. ./dserver-linux-amd64
```

`DTAIL_NO_ZSTD=yes` sets the `nozstd` build tag so the binary does not link DataDog’s CGO zstd (required for static cross-compiles). **`.zst` log files are not supported** in that binary; gzip still works.

## Installation checklist (each server)

Do this on **each** target (pi0–pi3 and/or r0–r2). Adjust **user** if you are not using `paul` on the node.

1. **Binary**: `/usr/local/bin/dserver`, mode `0755`, owned by root.
2. **OS user**: `dserver` system account (`useradd -r -d /var/lib/dserver -s /sbin/nologin -U dserver`).
3. **Directories**: `/etc/dserver`, `/var/run/dserver` (tmpfs — recreated at boot; use systemd `RuntimeDirectory` in the example unit if you adopt it).
4. **Config**: `/etc/dserver/dtail.json` from `examples/dtail.json.example` — ensure **Server.Permissions.Users** includes every login name that will connect (e.g. `paul`, `root`).
5. **systemd**: `examples/dserver.service.example` → `/etc/systemd/system/dserver.service` — unit stays **disabled** by default; start with `systemctl start dserver`.
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
dcat --servers pi0.lan,pi1.lan,pi2.lan,pi3.lan /etc/os-release
dcat --servers r0.lan,r1.lan,r2.lan /etc/hostname
```

Use hostnames that resolve from where you run the client (often `*.lan.buetow.org`).

## k3s / r0–r2 notes

- **amd64** binaries only; do not deploy the Pi **arm64** build there.
- Same **2222** and **firewalld** rules apply.
- These VMs are heavier than the Pis; defaults in `dtail.json` (`MaxConcurrentCats`, etc.) can be raised if needed.
- Full install sequence for these three nodes: section **dserver on r0, r1, r2** above.

## Related upstream fixes (f3s-relevant)

- **Host key file**: first boot uses `RootedPath.Stat` + `errors.Is(…, fs.ErrNotExist)` so missing `cache/ssh_host_key` triggers generation (older `os.IsNotExist` missed wrapped errors).
- **Known-hosts prompt deadlock**: `internal/io/dlog/loggers/stdout.go` must not hold its mutex across the pause/resume wait when the trust prompt runs.
