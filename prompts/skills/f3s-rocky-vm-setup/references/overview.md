# Rocky VM Overview

The `rocky` VM's role and host/IP details are in the skill's [`SKILL.md`](../SKILL.md);
this reference covers the setup detail (SSH keys, tooling, privileges, replication).

## SSH Keys

| Key | Path | Purpose |
|-----|------|---------|
| Root VM key | `/root/.ssh/id_ed25519` | Host/admin SSH |
| Paul VM key | `/home/paul/.ssh/id_ed25519` | Host/admin SSH |
| Forgejo key | `/home/paul/.ssh/id_ed25519_forgejo` | Passphrase-less git+ssh to Forgejo as user `rocky` |

Forgejo push setup (client key + `~/.ssh/config`) is in [git-remotes.md](git-remotes.md). Server-side user/team lives in [`f3s-workloads` Forgejo](../../f3s-workloads/references/forgejo.md#rocky-push-access).

```sh
# Regenerate host keys if needed
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519 -C 'root@rocky.f3s.lan.buetow.org'
ssh-keygen -t ed25519 -N '' -f /home/paul/.ssh/id_ed25519 -C 'paul@rocky'
```

## /etc/hosts

Short LAN aliases for all f3s hosts (short, `.lan`, and `.lan.buetow.org` variants):

```
# f3s k3s node LAN aliases
192.168.1.120 r0 r0.lan r0.lan.buetow.org
192.168.1.121 r1 r1.lan r1.lan.buetow.org
192.168.1.122 r2 r2.lan r2.lan.buetow.org

# f3s FreeBSD host LAN aliases
192.168.1.130 f0 f0.lan f0.lan.buetow.org
192.168.1.131 f1 f1.lan f1.lan.buetow.org
192.168.1.132 f2 f2.lan f2.lan.buetow.org
192.168.1.133 f3 f3.lan f3.lan.buetow.org

# f3s Raspberry Pi LAN aliases
192.168.1.125 pi0 pi0.lan pi0.lan.buetow.org
192.168.1.126 pi1 pi1.lan pi1.lan.buetow.org
192.168.1.127 pi2 pi2.lan pi2.lan.buetow.org
192.168.1.128 pi3 pi3.lan pi3.lan.buetow.org
```
