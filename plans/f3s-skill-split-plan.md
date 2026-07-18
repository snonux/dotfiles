# Plan: Split the `f3s` skill into smaller sibling skills

Task: **us0** — "look at skill f3s, it has many references within the skill; make a
plan to create multiple skills out of it so the f3s skill becomes smaller."

This is a **planning-only** document. No skill files are created, moved, or deleted
here. A future task executes the migration described below.

---

## 1. Where the skill lives (repo scoping)

- `~/.claude/skills` is a symlink chain that resolves into this repo:
  `~/.claude/skills` → `~/Notes/Prompts/skills` → `/home/paul/git/dotfiles/prompts/skills`.
- Verified: `git -C ~/.claude/skills/f3s rev-parse --show-toplevel` →
  `/home/paul/git/dotfiles` (the **same** tree as this dotfiles repo).
- Consequence: the f3s skill and its future siblings **are committable within
  dotfiles**. A new directory created under
  `/home/paul/git/dotfiles/prompts/skills/<name>/` automatically appears under
  `~/.claude/skills/<name>/` through the symlink — **no per-skill symlink is
  needed**.
- This plan document itself lives at `plans/f3s-skill-split-plan.md` (a new
  `plans/` directory), deliberately **outside** `prompts/skills/` so it is never
  loaded as skill content.

---

## 2. Current state (grounded numbers)

`prompts/skills/f3s/SKILL.md` — **120 lines / ~13.3 KB**. It is *mostly* a
"Reference Files" index, but it also **re-inlines** three large sections that
duplicate their own reference files (a DRY violation flagged by the
`skill-maintenance` sub-division rules):

- "Raspberry Pi Nodes" + "Webserver Configuration" (SKILL.md lines ~70–110) ⇄
  duplicates `references/bootstrap-netbsd-pi.md` and `references/pihole-pi.md`.
- "DTail (dserver)" (SKILL.md lines ~111–115) ⇄ duplicates `references/dtail.md`.

`references/` — **38 files, ~4846 lines total.** Line counts by file:

| Cluster | Files (lines) |
|---|---|
| **FreeBSD host / bhyve layer** | hardware.md (60), freebsd-setup.md (202), ups-power.md (77), console-jetkvm-shutdown.md (118), shelly-plug.md (120), rocky-linux-vms.md (226), bootstrap-rocky-bhyve.md (251), f3-rocky-vm.md (113) |
| **Networking** | wireguard.md (309), remote-access.md (90) |
| **Storage** (already an index + subfolder) | storage.md (29) → storage/{zfs 90, zrepl 237, carp 95, nfs 204, nfs-mount-monitor 107, troubleshooting 198, usb-keys 116, backups 40} |
| **k3s** (already an index + subfolder) | k3s-setup.md (12) → k3s-setup/{install 169, remote-access 108, ingress 120, troubleshooting 49}; r-node-deploy.md (144) |
| **Observability** (already an index + subfolder) | observability.md (35) → observability/{stack 158, freebsd 112} |
| **Raspberry Pi nodes** | bootstrap-netbsd-pi.md (337), pihole-pi.md (45) |
| **Workloads (k8s apps)** | immich.md (98), garage.md (158), player.md (167), ychat.md (82), goprecords-uptimed.md (130) |
| **DTail / dserver** | dtail.md (233), dserver.d (7) |

Existing siblings already carved out of f3s (precedent for this pattern):
`pkgrepo` (package repositories) and `rocky-vm-setup` (the plain `rocky` VM).

---

## 3. Design principles applied

- **Index pattern** (from `skill-maintenance/references/sub-division.md`): each
  carved-out skill is a slim `SKILL.md` (overview + When to Use + Reference Files
  list + optional tiny quick-reference) with all detail in `references/`.
- **DRY — one canonical home per fact.** Nothing is copied; content is *moved*
  and everything else *cross-links*. Canonical homes after the split:
  - **Master host/IP inventory** → stays in `f3s/SKILL.md` (the "Quick Reference:
    Host IPs" table). Every sibling links back to it instead of copying rows.
  - **WireGuard mesh / IP assignments** → stays in `f3s/references/wireguard.md`.
  - **zrepl config** → moves with storage into `f3s-storage`
    (`rocky-vm-setup` already cross-links this file — see §7).
  - **DTail package build** stays owned by `pkgrepo`; **DTail dserver
    deployment/ops** becomes the `f3s-dtail` skill (see §5.6).
- **Self-triggering descriptions.** Each new `SKILL.md` frontmatter `description`
  (≤1024 chars, lowercase-`name` ≤64, hyphens) carries distinct keywords so the
  agent loads the *right* skill for a task instead of the whole f3s bundle.
- **Refs one level deep.** Subfolders (`storage/`, `k3s-setup/`,
  `observability/`) migrate wholesale — they are already correctly nested.

### Naming convention — DECIDED: `f3s-` prefix on all carve-outs

**Decision (confirmed by the user):** every carve-out keeps the **`f3s-` prefix** so
they read as one family and sort together right next to the `f3s` skill, making it
obvious they belong together: `f3s-storage`, `f3s-k3s`, `f3s-workloads`,
`f3s-raspberry-pi`, `f3s-observability`, `f3s-dtail`. This is spec-valid (lowercase,
hyphens, ≤64 chars) and is applied uniformly to all six.

Note this is a **prefix**, not a trailing suffix (`f3s-storage`, not `storage-f3s`):
a prefix is what groups them alphabetically beside `f3s`. The existing siblings
`pkgrepo` and `rocky-vm-setup` stay unprefixed (they are not being renamed); only the
new f3s carve-outs take the `f3s-` marker. The earlier unprefixed `homelab-*`
alternative is rejected.

---

## 4. Proposed target structure

`f3s` shrinks to a **hub/index skill**: overview, When to Use, the master Host-IP
table, the FreeBSD-host + networking references (the connective tissue every other
skill depends on), and a "Related skills" list cross-linking the carve-outs.

**Stays in `f3s`:** `hardware.md`, `freebsd-setup.md`, `ups-power.md`,
`console-jetkvm-shutdown.md`, `rocky-linux-vms.md`, `bootstrap-rocky-bhyve.md`,
`f3-rocky-vm.md`, `shelly-plug.md`, `wireguard.md`, `remote-access.md`.
(Rationale: the physical hosts, bhyve layer, power, WireGuard mesh, and off-LAN
access are cross-cutting context that all other skills reference — the hub keeps
them so cross-links point *inward* to one stable place.)

**Carved out** into six sibling skills (§5). After the split f3s drops from 38
reference files to **10**, and the SKILL.md loses its three inlined duplicate
sections.

---

## 5. New skills — one section each

Each subsection gives: proposed `name`, a spec-style one-line `description`, exactly
what moves in, and what the f3s hub keeps as a one-line index entry.

### 5.1 `f3s-storage` — highest priority, cleanest move

- **description:** "Reference skill for the f3s homelab storage layer: ZFS
  (`zdata`), zrepl replication, CARP storage VIP (f0/f1, `f3s-storage-ha`
  192.168.1.138), NFS over stunnel, the nfs-mount-monitor watchdog, USB key
  material, local-path/backups, and storage troubleshooting (incl. thermal). Use
  when working on homelab storage, ZFS/zrepl, NFS mounts, CARP failover, or disk
  issues."
- **Moves in:** `references/storage.md` → **becomes this skill's `SKILL.md`**
  (converted from index-into-subfolder to a full skill index); the entire
  `references/storage/` subfolder (`zfs.md`, `zrepl.md`, `carp.md`, `nfs.md`,
  `nfs-mount-monitor.md`, `troubleshooting.md`, `usb-keys.md`, `backups.md`) →
  `f3s-storage/references/` (flatten one level: the files sit directly under the
  new skill's `references/`).
- **f3s keeps:** one bullet under "Related skills": *Storage → `f3s-storage`
  skill*.
- **Why first:** it is the largest cluster (~1116 lines) and is *already* an
  index+subfolder, so the move is almost mechanical.

### 5.2 `f3s-k3s` — k3s cluster

- **description:** "Reference skill for the f3s k3s Kubernetes cluster: 3-node HA
  install on r0/r1/r2 Rocky VMs (bootstrap, kubeconfig, PVs, ArgoCD), off-LAN
  access (jump via OpenBSD frontend → root@r0.wg0 → kubectl), ingress (relayd,
  cert-manager), etcd recovery, and the reusable Rex r-node rollout. Use when
  installing, accessing, or troubleshooting the k3s cluster or deploying to r0/r1/
  r2."
- **Moves in:** `references/k3s-setup.md` → **becomes this skill's `SKILL.md`**;
  `references/k3s-setup/` (`install.md`, `remote-access.md`, `ingress.md`,
  `troubleshooting.md`) → `f3s-k3s/references/`; `references/r-node-deploy.md` →
  `f3s-k3s/references/r-node-deploy.md`.
- **f3s keeps:** *k3s cluster → `f3s-k3s` skill*.

### 5.3 `f3s-observability` — monitoring stack

- **description:** "Reference skill for the f3s homelab observability stack:
  Prometheus, Grafana Alloy, Loki, Tempo, and alerting on the k3s cluster, plus
  FreeBSD host monitoring (node_exporter + recording rules). Use when working on
  metrics, logs, traces, dashboards, or alerts for the homelab."
- **Moves in:** `references/observability.md` → **becomes this skill's
  `SKILL.md`**; `references/observability/` (`stack.md`, `freebsd.md`) →
  `f3s-observability/references/`.
- **f3s keeps:** *Observability → `f3s-observability` skill*.

### 5.4 `f3s-raspberry-pi` — the four Pi nodes

- **description:** "Reference skill for the four Raspberry Pi 3 nodes of the f3s
  homelab: pi0/pi1 run NetBSD 10.1 (aarch64) serving static f3s.buetow.org /
  snonux.foo via bozohttpd behind OpenBSD relayd over WireGuard; pi2/pi3 run Rocky
  Linux 9 with Pi-hole in Docker and LAN wildcard DNS (`*.f3s.lan.buetow.org` →
  192.168.1.138). Covers doas/pkgin bootstrap, bozohttpd vhosting, npf, uptimed,
  content sync, and the doas-alias shutdown pitfall. Use when configuring or
  troubleshooting the Pi nodes, the static site, or Pi-hole/LAN DNS."
- **Moves in:** `references/bootstrap-netbsd-pi.md`, `references/pihole-pi.md` →
  `f3s-raspberry-pi/references/`. **Plus** the inlined SKILL.md sections
  "Raspberry Pi Nodes" and "Webserver Configuration" — that prose moves into this
  skill's `SKILL.md`/references (this **fixes** the DRY duplication in §2).
- **f3s keeps:** *Raspberry Pi nodes → `f3s-raspberry-pi` skill* (one bullet; the
  master IP table rows for pi0–pi3 stay in the f3s hub table).

### 5.5 `f3s-workloads` — the hosted applications

- **description:** "Reference skill for the application workloads running on the
  f3s homelab: Immich (photos), Garage (S3), the Player service, yChat (legacy C++
  chat), and goprecords/uptimed uploads. Covers image build/push, Helm charts,
  ArgoCD sync, NFS PV/PVC wiring, edge domain routing, and per-app
  troubleshooting. Use when deploying, updating, or debugging a specific homelab
  application."
- **Moves in:** `references/immich.md`, `references/garage.md`,
  `references/player.md`, `references/ychat.md`,
  `references/goprecords-uptimed.md` → `f3s-workloads/references/`.
- **f3s keeps:** *Hosted applications (Immich/Garage/Player/yChat/goprecords) →
  `f3s-workloads` skill*.
- **Note:** `ychat.md` explicitly declares itself "the single home for f3s
  deployment details" — preserve that canonical-home claim in the moved file.

### 5.6 `f3s-dtail` — dserver deployment/ops (recommended)

- **description:** "Reference skill for DTail/dserver deployment across the f3s
  fleet: distributed log access over SSH on port 2222 — Pis arm64 (NetBSD +
  Rocky) vs r0–r2 amd64, r-VM root + root.authorized_keys cache, firewalld/npf
  2222 rules, systemd timers. Package building lives in the `pkgrepo` skill. Use
  when deploying, configuring, or troubleshooting dserver on homelab hosts."
- **Moves in:** `references/dtail.md`, `references/dserver.d` →
  `f3s-dtail/references/`. **Plus** the inlined SKILL.md "DTail (dserver)"
  section (fixes the remaining DRY duplication in §2).
- **f3s keeps:** *DTail / dserver → `f3s-dtail` skill*.
- **Boundary with `pkgrepo`:** `pkgrepo` owns *package building/publishing*
  (`dtail-package.md`); `f3s-dtail` owns *runtime deployment/operations*. Keep the
  existing link `dtail.md` → `../../pkgrepo/references/package-repos.md` — the path
  depth is unchanged (`skills/<x>/references/` → `../../pkgrepo/...`), so it stays
  valid after the move.
- **Alternative:** if a separate skill feels too granular, fold `dtail.md` into
  `pkgrepo` instead. Recommendation: keep it separate — deployment/ops vs
  packaging are distinct trigger contexts.

---

## 6. What the slim `f3s` hub looks like afterwards

```
f3s/SKILL.md         (overview, When to Use, master Host-IP table,
                      "Reference Files" for the 10 host/network refs,
                      "Related skills" cross-links to the 6 carve-outs)
f3s/references/
  hardware.md  freebsd-setup.md  ups-power.md  console-jetkvm-shutdown.md
  rocky-linux-vms.md  bootstrap-rocky-bhyve.md  f3-rocky-vm.md
  shelly-plug.md  wireguard.md  remote-access.md
```

The three inlined duplicate sections are deleted from SKILL.md (their content now
lives once, in `f3s-raspberry-pi` and `f3s-dtail`). SKILL.md gains a short
"Related skills" block:

```
## Related skills
- f3s-storage        — ZFS, zrepl, CARP, NFS/stunnel, backups
- f3s-k3s            — k3s cluster install, ingress, ArgoCD, etcd, r-node Rex
- f3s-observability  — Prometheus/Alloy/Loki/Tempo, node_exporter
- f3s-raspberry-pi   — pi0/pi1 NetBSD static site, pi2/pi3 Pi-hole/DNS
- f3s-workloads      — Immich, Garage, Player, yChat, goprecords
- f3s-dtail          — dserver deployment/ops (port 2222)
- pkgrepo            — package repositories (existing)
- rocky-vm-setup     — the plain `rocky` VM on f3 (existing)
```

---

## 7. Cross-reference / broken-link fixes (do these as part of each move)

These links exist **today** and will break unless updated. Path rule: a link
between two skills is `../../<other-skill>/references/<file>.md` (both skills sit
at `skills/<name>/references/`, same depth).

**Internal f3s links that become cross-skill links:**

| File (after move) | Current link | New link |
|---|---|---|
| `f3s-k3s/references/install.md:12` | `../wireguard.md` | `../../f3s/references/wireguard.md` |
| `f3s-k3s/references/install.md:13` | `../rocky-linux-vms.md` | `../../f3s/references/rocky-linux-vms.md` |
| `f3s-k3s/references/install.md:110` | `../storage/nfs.md` | `../../f3s-storage/references/nfs.md` |
| `f3s-k3s/references/install.md:111` | `../storage/nfs-mount-monitor.md` | `../../f3s-storage/references/nfs-mount-monitor.md` |
| `f3s-k3s/references/troubleshooting.md:49` | `../storage/troubleshooting.md` | `../../f3s-storage/references/troubleshooting.md` |
| `f3s-observability/references/stack.md:71` | `../k3s-setup/install.md` | `../../f3s-k3s/references/install.md` |

**External skills that link INTO f3s (update these repos' skills too):**

| File | Current reference | Fix |
|---|---|---|
| `rocky-vm-setup/references/zrepl.md:12` | `skills/f3s/references/storage/zrepl.md` | → `skills/f3s-storage/references/zrepl.md` |
| `rocky-vm-setup/SKILL.md:29` (prose) | "full config in `f3s` skill" | → point to `f3s-storage` |
| `pkgrepo/SKILL.md:35` (prose) | "the `f3s` skill's `bootstrap-netbsd-pi.md`" | → "the `f3s-raspberry-pi` skill" |
| `pkgrepo/references/client-setup.md:104` (prose) | "the `f3s` skill's `bootstrap-netbsd-pi.md`" | → "the `f3s-raspberry-pi` skill" |

**Stays valid (no change needed):** `f3s-dtail/references/dtail.md:205` →
`../../pkgrepo/references/package-repos.md` (same nesting depth after the move).

**f3s/SKILL.md index entries** for every moved topic must be rewritten from
`[Topic](references/<file>.md)` bullets into the "Related skills" cross-links shown
in §6.

---

## 8. Execution order (for the future implementation task)

Do the carve-outs **one at a time**, cleanest first, verifying links after each:

1. **`f3s-storage`** (largest, already a subfolder index — lowest risk). Move
   files, promote `storage.md` → `SKILL.md`, write frontmatter, fix the inbound
   `rocky-vm-setup/references/zrepl.md` link, update f3s SKILL.md.
2. **`f3s-k3s`** (also a subfolder index). Move files, promote `k3s-setup.md`,
   fix the 5 outbound links in §7, add `r-node-deploy.md`.
3. **`f3s-observability`** (subfolder index). Move, promote, fix `stack.md`→k3s
   link.
4. **`f3s-workloads`** (flat file cluster — no subfolder). Create skill, move 5
   files, write a fresh `SKILL.md` index, preserve ychat's canonical-home note.
5. **`f3s-raspberry-pi`** (flat cluster + de-inline). Move 2 files, **move the
   inlined SKILL.md Pi/webserver prose out**, update `pkgrepo` prose links.
6. **`f3s-dtail`** (flat cluster + de-inline). Move `dtail.md`/`dserver.d`, move
   the inlined DTail section out.
7. **Slim `f3s/SKILL.md`**: rebuild the "Reference Files" list to the 10 remaining
   host/network refs, add the "Related skills" block, keep the master Host-IP
   table as the single canonical inventory.
8. **Verify** (per `skill-maintenance` "After sub-dividing"): no information lost
   (moved, not deleted); every SKILL.md bullet resolves; no SKILL.md duplicates a
   reference; all cross-skill links resolve. Grep sweep:
   `grep -rn "references/storage\|references/k3s-setup\|references/observability\|bootstrap-netbsd-pi\|pihole-pi\|dtail" prompts/skills/` should return **only** the new skills and updated cross-links.
9. Commit with `commit-skills`, or a normal dotfiles commit.

For each new skill, write valid frontmatter (`name`, `description`) and validate
with `pi` — a missing `description` means the skill never loads.

---

## 9. Risks & watch-items

- **Broken cross-references** (§7) are the primary risk — six internal links, four
  external prose/link references. Fix them in the same commit as each move.
- **Symlink/discovery:** none needed — `~/.claude/skills` resolves into
  `prompts/skills/`, so new dirs appear automatically. But confirm each new
  `SKILL.md` is picked up (`pi` skill list) after creation.
- **Description keyword overlap:** all six carve-outs mention "f3s homelab". Make
  the *distinguishing* keywords strong (storage/ZFS, k3s/kubernetes, Pi/Pi-hole,
  Immich/Garage, dserver) so the agent doesn't load the wrong one — and so it
  still loads `f3s` (the hub) for host/network/context questions.
- **DRY regressions:** the master Host-IP table and WireGuard IPs stay canonical in
  f3s; carve-outs must *link*, not copy rows. Watch that de-inlining the Pi/DTail
  sections doesn't leave a trimmed copy behind in SKILL.md.
- **Scope creep:** `wireguard.md` (309 lines) and `remote-access.md` are tempting
  to carve into an `f3s-network` skill, but they are the connective tissue every
  other skill links to — keeping them in the hub keeps cross-links pointing to one
  stable place. Revisit only if the hub is still too large after the six splits.
- **pkgrepo/rocky-vm-setup live in the same dotfiles repo**, so their link fixes
  are committable here too (no foreign-repo problem).

---

## 10. Summary of the proposed split

| New skill | Moves in | Approx. lines |
|---|---|---|
| `f3s-storage` | storage.md + storage/ (8 files) | ~1116 |
| `f3s-k3s` | k3s-setup.md + k3s-setup/ (4) + r-node-deploy.md | ~602 |
| `f3s-workloads` | immich, garage, player, ychat, goprecords-uptimed | ~635 |
| `f3s-raspberry-pi` | bootstrap-netbsd-pi, pihole-pi + inlined Pi/webserver prose | ~420 |
| `f3s-observability` | observability.md + observability/ (2) | ~305 |
| `f3s-dtail` | dtail.md, dserver.d + inlined DTail prose | ~245 |
| **`f3s` (hub, remains)** | hardware, freebsd-setup, ups-power, console-jetkvm-shutdown, rocky-linux-vms, bootstrap-rocky-bhyve, f3-rocky-vm, shelly-plug, wireguard, remote-access + host-IP table | ~1670 |

Result: `f3s` goes from **38** reference files to **10**, sheds its three inlined
duplicate sections, and becomes a clean hub that cross-links six focused sibling
skills (alongside the existing `pkgrepo` and `rocky-vm-setup`).
