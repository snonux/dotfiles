# Uptimed / uprecords collection via goprecords

Central uptime stats come from **`uptimed`** record files aggregated by **[goprecords](https://codeberg.org/snonux/goprecords)**. The live API is **`https://goprecords.f3s.buetow.org`** (k3s **services** namespace; stats PVC; auth DB **`goprecords-auth.db`**).

## Daemon and keys

- **Read API:** `GET /report` (Plaintext, Markdown, Gemtext, HTML).
- **Upload API:** `PUT /upload/{HOSTNAME}/{kind}` with kinds `records`, `txt`, `cur.txt`, `os.txt`, `cpuinfo.txt`.
- **Keys:** issued only on the server, e.g.  
  `kubectl exec -n services deployment/goprecords -- goprecords --create-client-key HOST -stats-dir=/data/stats`  
  Re-issuing replaces the previous token; update every client that uses that host name.

The **`HOSTNAME`** in the URL must match the name passed to **`--create-client-key`**. Use stable short names (**`f0`**, **`pi2`**, **`fishfinger`**, …) consistent with stats file basenames. That short name is only for **`GOPRECORDS_HOST`** and upload URLs — not for SSH.

## SSH / DNS (f3s)

- **`f0.lan` is not a hostname** (it will not resolve). Use the **full** name **`f0.lan.buetow.org`**, or the **LAN IP** from the f3s table (**`192.168.1.130`** for **f0**, **`.131`–`.133`** for **f1**–**f3**).
- **FreeBSD Beelinks and Pis:** **`ssh -p 22 paul@…`** (default SSH port). Your **`~/.ssh/config`** may use **port 2** for **OpenBSD frontends** only — that does **not** apply to **f0**–**f3** or **pi0**–**pi3**.
- **Pis:** **`pi0.lan.buetow.org`** … **`pi3.lan.buetow.org`** (full FQDN), port **22**.
- **Manual upload test over SSH:** Beelinks use **`doas env GOPRECORDS_HOST=fN /usr/local/bin/goprecords-upload-client.sh`** (not **`sudo`** — often absent). Pis use **`sudo env GOPRECORDS_HOST=piN …`**.

## Where it is documented in-repo

In **goprecords** **`README.md`**:

- HTTP API and upload **`curl`** examples
- **“Setting up a new upload client”** (generic)
- **“Manual hourly upload (single host, not config-managed)”** — POSIX script **`contrib/goprecords-upload-client.sh`**, **FreeBSD** hourly **`cron`** (with **`PATH`**), **Linux** **`systemd`** **`oneshot` + `timer`**

Install **`curl`** and **`uptimed`** on every client that uploads.

## By host class (f3s)

| Class | Hosts | Automation | Notes |
|--------|--------|------------|--------|
| OpenBSD frontends | **fishfinger**, **blowfish** | **Rex** **`goprecords_upload`** in **`~/git/conf/frontends`**; **`/etc/daily.local`** runs **`/usr/local/bin/goprecords-upload.sh`** once per **day** | Tokens in **geheim** **`secrets/etc/goprecords/<host>.token`**; template **`scripts/goprecords-upload.sh.tpl`** |
| FreeBSD (Beelinks) | **f0**–**f3** (LAN **`192.168.1.130`–`133`**) | Manual **hourly** **root** **`cron`** calling **`goprecords-upload-client.sh`** with **`GOPRECORDS_HOST=f0`** … **`f3`** | **`/var/db/uptimed/records`**; SSH: **`fN.lan.buetow.org`** or **`192.168.1.(130+N)`** for **fN**, **`-p 22`** |
| Raspberry Pi (Rocky) | **pi2**–**pi3** | Manual **hourly** **systemd** **timer** (see README) | **`/var/spool/uptimed/records`**; SSH: **`piN.lan.buetow.org`**, **`-p 22`** |
| Raspberry Pi (NetBSD) | **pi0**–**pi1** | Manual **hourly** **root** **`cron`** (no systemd) calling **`goprecords-upload-client.sh`** with **`GOPRECORDS_HOST=pi0`**/**`pi1`** | **`/var/spool/uptimed/records`** (uptimed built from source — no prebuilt aarch64 pkgsrc package); SSH: **`piN.lan.buetow.org`**, **`-p 22`** |
| Fedora laptop | **earth** | **user** **systemd** **`oneshot` + hourly timer** `goprecords-upload-earth.{service,timer}` | Service sets **`Environment=GOPRECORDS_HOST=earth`** and runs **`~/.local/bin/goprecords-upload-earth.sh`**; token **`~/.config/goprecords-upload-earth/token`** |
| Mac (uptimed) → published by earth | **mega-m3-pro** (raw host `MBDVXJ4XKH9C`) | Mac drops records into the **worktime** git repo; **earth** pushes them via a **second `ExecStart`** in `goprecords-upload-earth.service` | See [Mac / mega-m3-pro via earth](#mac--mega-m3-pro-via-earth) below |

## OpenBSD frontends (Rex)

From **`~/git/conf/frontends`**:

```bash
rex goprecords_upload
# or full commons
rex commons
```

See **`frontends/README.md`** (section **goprecords upload**).

## Manual clients (FreeBSD + Pis + earth)

The canonical unified script is **`scripts/goprecords-upload-client.sh`** (also mirrored in **`contrib/`**). It is POSIX sh and works on all host types:

- **root** (FreeBSD/Linux): token at **`/etc/goprecords-upload.token`** (**`0600`**)
- **non-root** (earth user session): token at **`$XDG_CONFIG_HOME/goprecords-upload-<HOST>/token`**

Copy to **`/usr/local/bin/`** (system) or **`~/.local/bin/`** (user), set **`GOPRECORDS_HOST`** per machine (**cron** **`env`** or **`systemd`** **`Environment`**/**`EnvironmentFile`**). Full snippets: **goprecords** **`README.md`**.

> **earth gotcha:** `goprecords-upload-earth.sh` is a *copy of the generic* `goprecords-upload-client.sh`, so it aborts with `set GOPRECORDS_HOST` unless the var is provided. The service therefore **must** carry `Environment=GOPRECORDS_HOST=earth`. (A missing env var silently broke earth uploads for ~a month — symptom: stale timestamp on the report, service `status=1/FAILURE` with `set GOPRECORDS_HOST` in `journalctl --user -u goprecords-upload-earth`.)

## Mac / mega-m3-pro via earth

The Mac (Apple Silicon, **`Darwin`**) is **not** a direct upload client. Instead:

The logic lives in a **fish helper kept in the (private) worktime repo**, **`~/git/worktime/scripts/uprecords-sync.fish`** (functions `worktime::uprecords::darwin::collect` / `…::import`), so host-specific details stay out of the public dotfiles repo. `dotfiles/fish/conf.d/worktime.fish` **`source`**s it, and **`worktime::supersync`** calls both functions.

1. On the Mac, **`worktime::uprecords::darwin::collect`** copies the local **uptimed** records into the **worktime** git repo as
   **`uprecords-MBDVXJ4XKH9C.records`** and **`uprecords-MBDVXJ4XKH9C.txt`**, and they get synced via `git` (part of **`worktime::supersync`**). Guards on `uname = Darwin`.
2. On **earth** (the only host that publishes), **`worktime::uprecords::darwin::import`** reads those repo files and **`PUT`**s them to goprecords, **re-labelling** the raw host `MBDVXJ4XKH9C` → **`mega-m3-pro`**:
   - `PUT /upload/mega-m3-pro/records` and `PUT /upload/mega-m3-pro/txt`
   - token at **`~/.config/goprecords-upload-mega-m3-pro/token`** (`0600`).
   - Guards on `hostname = earth`; exits cleanly (warning) if the token is missing.
3. Automation: `goprecords-upload-earth.service` has a **second `ExecStart`** that runs the import hourly alongside earth's own upload:
   ```ini
   ExecStart=%h/.local/bin/goprecords-upload-earth.sh
   ExecStart=/usr/local/sbin/fish -c worktime::uprecords::darwin::import
   ```
   The import is a **no-op off earth** (guards on `hostname = earth`) and exits cleanly with a warning if the `mega-m3-pro` token is absent, so it never fails the service.

**Token note:** each token is bound to its host name server-side — the **earth** token returns **403** for `mega-m3-pro`. Issue a dedicated key (see *Daemon and keys* above):
```sh
kubectl exec -n services deployment/goprecords -- \
  goprecords --create-client-key mega-m3-pro -stats-dir=/data/stats
```
Re-issuing **replaces** any previous `mega-m3-pro` token (the Mac used to upload directly until it switched to the repo route). When roaming, reach the cluster via the OpenBSD frontend jump (see [k3s remote access](k3s-setup/remote-access.md)), then store the printed token in `~/.config/goprecords-upload-mega-m3-pro/token` on earth.

## Related conf repo paths

- Kubernetes Helm: **`conf/f3s/goprecords/`** (image, PVC, ingress **`goprecords.f3s.buetow.org`**)
- OpenBSD Rex: **`conf/frontends/`** (**`Rexfile`**, **`scripts/goprecords-upload.sh.tpl`**)
