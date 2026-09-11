# gonf (dotfiles)

Fedora laptop configuration managed with [gonf](https://github.com/snonux/gonf).
Replaces the top-level `Rexfile` for this host (`earth`).

## Layout

```text
cmd/gonf/main.go   # RegisterMethods + aggregate home; api.CLI()
internal/paths/    # HOME / Dot / DotPrivate roots
internal/tasks/    # Home and Pkg task methods
```

## Build

```bash
cd ~/git/dotfiles/gonf
go build -o gonf ./cmd/gonf
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
```
