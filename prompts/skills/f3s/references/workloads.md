# f3s Workloads (area index)

The application workloads hosted on the f3s k3s cluster. Each app has its own
reference with image build/push steps, Helm chart path, ArgoCD wiring, and NFS
PV/PVC notes.

## When to Use

- Deploying, updating, or debugging one of the hosted homelab applications below
- Questions about a specific app's image build/push, Helm chart, ArgoCD sync, or storage wiring
- Reading or summarizing the unread RSS feeds in Miniflux
- Refreshing, publishing or syncing the irregular.ninja photo album
- For the cluster these run on, see [k3s cluster](k3s.md); for the NFS/PV storage layer, [Storage](storage.md); for hosts/IPs, the [hub](../SKILL.md).

## Topic Files

- [Immich](workloads/immich.md) — photo server deployment, job queue stats, troubleshooting
- [Player](workloads/player.md) — `player.f3s.buetow.org`, image build/push workflow, Helm chart path, ArgoCD sync, NFS PV/PVC notes, transcoding, end-to-end tests
- [yChat](workloads/ychat.md) — `ychat.f3s.lan.buetow.org`, legacy C++ chat server, image build/push, Helm chart + ArgoCD; the single home for f3s yChat deployment details
- [Forgejo](workloads/forgejo.md) — `code.f3s.buetow.org`, git forge (80+ repos, ArgoCD's own source), architecture, crawler/relayd alt-port, hostname drift, `rocky` user + snonux Writers push access (client key in [rocky VM git remotes](rocky-vm/git-remotes.md))
- [goprecords / uptimed uploads](workloads/goprecords-uptimed.md) — `https://goprecords.f3s.buetow.org`; gonf pairs uptimed + upload for frontends, f-hosts, Pis, earth/zen; keys, Mac/mega-m3-pro via earth, Rocky Pi chrony drop-in
- [Miniflux news](workloads/miniflux-news.md) — fetch, summarize, drill into and mark-as-read the unread RSS entries on `https://flux.f3s.buetow.org` through the Miniflux API (token in `~/.flux_token`)

Static sites served by the OpenBSD frontends:

- [irregular.ninja](workloads/irregular-ninja.md) — regenerate the photo album with `shuriken` (`shuriken --generate` in `~/git/irregular.ninja/irregular.ninja`) and rsync `dist/` to `fishfinger` and `blowfish`; never sync the `cache/` directory

Garage (S3), four files; start with the first:

- [Garage](workloads/garage.md) — cluster topology on f0/f1/f2, local data and service setup, edge domain and frontend routing, the critical fix applied, existing buckets/keys, Prometheus, operational notes, recovery checklist for public endpoint issues
- [Garage S3 addressing](workloads/garage-s3-addressing.md) — path-style vs vhost-style addressing (read before wiring up a client), giving a bucket its own hostname
- [Garage commands](workloads/garage-commands.md) — cluster health, local and external S3 checks, creating an access key and granting it a bucket, the client credentials file and restoring it, bucket aliases, bucket/key workflow, authenticated S3 test
- [Garage clients](workloads/garage-clients.md) — known clients: watchos-app, Taskwarrior sync
