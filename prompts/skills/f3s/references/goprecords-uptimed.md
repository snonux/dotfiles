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
| Raspberry Pi (Rocky) | **pi0**–**pi3** | Manual **hourly** **systemd** **timer** (see README) | **`/var/spool/uptimed/records`**; SSH: **`piN.lan.buetow.org`**, **`-p 22`** |
| Fedora laptop | **earth** | Optional **user** **systemd** timer or manual | Example: **`~/.config/goprecords-upload-earth/`** |

## OpenBSD frontends (Rex)

From **`~/git/conf/frontends`**:

```bash
rex goprecords_upload
# or full commons
rex commons
```

See **`frontends/README.md`** (section **goprecords upload**).

## Manual clients (FreeBSD + Pis)

Copy **`contrib/goprecords-upload-client.sh`** to **`/usr/local/bin/`**, install token as **`/etc/goprecords-upload.token`** (**`0600`**, **root**), set **`GOPRECORDS_HOST`** per machine (**cron** **`env`** or **`systemd`** **`EnvironmentFile`**). Full snippets: **goprecords** **`README.md`**.

## Related conf repo paths

- Kubernetes Helm: **`conf/f3s/goprecords/`** (image, PVC, ingress **`goprecords.f3s.buetow.org`**)
- OpenBSD Rex: **`conf/frontends/`** (**`Rexfile`**, **`scripts/goprecords-upload.sh.tpl`**)
