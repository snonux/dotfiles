# gonf (dotfiles)

Fedora laptop configuration managed with [gonf](https://github.com/snonux/gonf).
Replaces the top-level `Rexfile` for this host (`earth`).

## Layout

```text
cmd/gonf/main.go   # RegisterMethods + aggregate home; api.CLI()
paths/             # HOME / Dot / DotPrivate roots
home/              # home_* tasks (HomeTasks methods: SyncDir / InstallFile / …)
pkg/               # pkg_* tasks (Pkg methods)
```

## Build

```bash
cd ~/git/dotfiles/gonf
mage deps    # go mod download
mage build   # compile ./gonf
# or just: mage
```

If `go mod tidy` cannot see a freshly tagged `github.com/snonux/gonf` release yet:

```bash
GOPROXY=direct GOSUMDB=off go mod tidy
```

## Usage

```bash
./gonf -version
./gonf -list
./gonf -profile=rocky -list     # override detected profile
./gonf -n home_scripts          # dry-run
./gonf home                     # all home_* tasks
./gonf pkg_fedora
./gonf home_helix home_tmux

# Remote (needs gonf ≥0.4.0 on the target PATH): stream plan over ssh, no local plan files
./gonf push -n user@host home_bash
./gonf push -- -p 2222 user@host home_helix home_tmux
```

On the target, `gonf` must resolve in non-interactive SSH sessions (e.g. install to a directory on the default PATH, or ensure `~/go/bin` is exported for `ssh host cmd`).
