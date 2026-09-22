# gonf (dotfiles)

Fedora laptop configuration managed with [gonf](https://github.com/snonux/gonf).
Replaces the top-level `Rexfile` for this host (`earth`).

## Layout

```text
cmd/gonf/main.go   # RegisterMethods + aggregate home; api.CLI()
paths/             # HOME / Dot / DotPrivate roots
tasks/             # Home and Pkg methods (SyncDir / InstallFile / …)
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

`pkg_fedora` is selected on the destination by the Fedora profile and runs its
package operations through the configured privileged apply path. `home_*`
tasks remain unprivileged; platform-specific tasks carry serializable
destination guards (Linux GOOS for systemd user units; fedora, rocky or
freebsd profile for QuickEdit — on FreeBSD pass `-profile=freebsd`, because
profile detection relies on `/etc/os-release`).

`home_systemd_user` composes its user units through the core `SystemdUnits`
helper (one change-gated daemon-reload, timers converge after it) and
`SystemdTimer` generates the simple wallpaper timer instead of syncing raw
unit files; the generated units keep the exact bytes of the former raw files
and normalize their mode to 0644. The remaining raw units under
`systemd-user/` keep their exact contents.
