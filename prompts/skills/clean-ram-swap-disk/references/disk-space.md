# Disk Space Cleanup

How to find and reclaim disk space on the Fedora laptop (`earth`). The
same authorization rules as the RAM workflow apply: an investigation request
is read-only, a cleanup request covers only the items the user approves.
Propose a table of candidates with sizes and commands, then run exactly the
approved rows.

## Misleading desktop warning

GNOME's housekeeping plugin (gsd-housekeeping) warns about **disk** space,
not RAM. In German, "Gerätespeicher fast voll" reads like "memory", so check
`df` before `free`. It fires when a volume has less than
`free-percent-notify` (5%) free *and* less than `free-size-gb-no-notify`
(1 GB) free:

```sh
gsettings list-recursively org.gnome.settings-daemon.plugins.housekeeping
```

A warning while `df` shows plenty of space usually means the disk filled up
for a short time (a large build, an image pull, agent scratch), or the
warning came from another volume. The notification names the volume.
Read-only snap squashfs mounts show 100% and do not matter.

## Measure

```sh
df -h -x tmpfs -x devtmpfs
findmnt -no FSTYPE /
sudo btrfs filesystem usage /     # root and /home share one btrfs volume
```

On btrfs, watch `Device unallocated` as well as free space. A nearly full
btrfs is hard to recover, so do not silence the warning with `ignore-paths`.

Use `dust` to break down usage (`dust -x -d 2 -n 25 -b <dir>`). A plain
`du` over `~` takes more than five minutes here, so run it in the
background or narrow it to one directory. `lsof +D` over large trees is just
as slow; prefer `/proc/*/cwd` and `pgrep -af` for checking what is in use.

## Usual large items

Seen on 2026-11-27 (835 GB used of 953 GB; 224 GB free after cleanup):

| Item | Size then | Reclaim |
|---|---|---|
| `~/.cache/go-build` | 57 GB | `go clean -cache` (rerun if a concurrent build makes it fail with "directory not empty") |
| `/usr/local/share/.cache/yarn` (root, from `sudo yarn global add`) | 34 GB | `sudo rm -rf /usr/local/share/.cache/yarn` |
| Ollama models in `/usr/share/ollama` | 58 GB | `ollama list`, then `ollama rm <name>` |
| GNOME search index `~/.cache/tracker3` | 15 GB | `localsearch reset -s` (the `tracker3` command is gone, and `localsearch` has no `-r`) |
| `/root/.npm` | 13 GB | `sudo rm -rf /root/.npm/_cacache`; user: `npm cache clean --force` |
| `~/.cache/uv` | 7.5 GB | `uv --no-config cache clean` (the uv config has a `system-certs` key this uv rejects) |
| yarn and ccache (user) | ~5 GB | `yarn cache clean`, `ccache -C` |
| Old kernel debuginfo (`/usr/lib/debug`) | 4.7 GB | `rpm -qa 'kernel-debuginfo*'`, then `sudo dnf remove` the old versions |
| systemd journal | 3.1 GB | `sudo journalctl --vacuum-size=500M` |

Caches rebuild on demand, so they are the safe first choice. The search
index refills after a reset; if it grows back, limit Settings → Search →
Search Locations so it skips `~/tmp` and `~/syncthing`.

## Agent scratch space

`~/tmp/claude` and `~/tmp/codex` hold per-session scratch from coding agents
(kernel build trees, `hfs-*` test images, thousands of `Test*` and
`public-t*` dirs); they were 283 GB in total. Other sessions are often
running tests in them, so:

- Size the old part first:
  `find ~/tmp/claude -mindepth 1 -maxdepth 1 -mtime +7 -print0 | du -csh --files0-from=-`
- Check for live work with `pgrep -af` and the newest descendant mtime, as
  for tmpfs artifacts in SKILL.md.
- Delete only entries older than the agreed age; leave recent build trees
  for the user to judge.

## Review, do not delete unasked

Personal data and tools: `~/syncthing`, `~/Pictures`, `~/Music`, `~/git`,
`~/.android/avd` (emulator images), `~/go` (module cache), `/var/lib/flatpak`
(check `flatpak list --unused` first). Report their sizes and leave the
decision to the user.

## Verify

Rerun `df -h /` and report free space before and after, each command's
result, and anything that failed and why.
