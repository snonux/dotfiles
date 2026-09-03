---
name: f3s-workloads
description: Reference skill for the application workloads running on the f3s homelab, Immich (photos), Garage (S3), the Player service, yChat (legacy C++ chat), Forgejo (git forge), and goprecords/uptimed uploads. Covers image build/push, Helm charts, ArgoCD sync, NFS PV/PVC wiring, edge domain routing, and per-app troubleshooting. Use when deploying, updating, or debugging a specific homelab application. Part of the f3s homelab skill family (hub, [`f3s`](../f3s/SKILL.md)).
---

# f3s Workloads

The application workloads hosted on the f3s k3s cluster. Each app has its own
reference with image build/push steps, Helm chart path, ArgoCD wiring, and NFS
PV/PVC notes.

## When to Use

- Deploying, updating, or debugging one of the hosted homelab applications below
- Questions about a specific app's image build/push, Helm chart, ArgoCD sync, or storage wiring
- For the cluster these run on, see [`f3s-k3s`](../f3s-k3s/SKILL.md); for the NFS/PV storage layer, [`f3s-storage`](../f3s-storage/SKILL.md); for hosts/IPs, the [`f3s`](../f3s/SKILL.md) hub.

## Reference Files

- [Immich](references/immich.md) — photo server deployment, job queue stats, troubleshooting
- [Garage](references/garage.md) — Garage cluster, edge domain routing, S3 bucket/key workflow, troubleshooting
- [Player](references/player.md) — `player.f3s.buetow.org`, image build/push workflow, Helm chart path, ArgoCD sync, NFS PV/PVC notes
- [yChat](references/ychat.md) — `ychat.f3s.lan.buetow.org`, legacy C++ chat server, image build/push, Helm chart + ArgoCD; the single home for f3s yChat deployment details
- [Forgejo](references/forgejo.md) — `code.f3s.buetow.org`, git forge (80+ repos, ArgoCD's own source), architecture, crawler/relayd alt-port, hostname drift, `rocky` user + snonux Writers push access (client key in [`f3s-rocky-vm-setup` git remotes](../f3s-rocky-vm-setup/references/git-remotes.md))
- [goprecords / uptimed uploads](references/goprecords-uptimed.md) — `https://goprecords.f3s.buetow.org`, `PUT /upload`, OpenBSD Rex daily vs FreeBSD/Pi manual hourly cron/systemd, upload client, geheim tokens
