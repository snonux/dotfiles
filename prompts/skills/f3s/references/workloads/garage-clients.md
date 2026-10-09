# Garage: known clients

## Known clients

### watchos-app

The original bucket, key alias `watchos-key`, path-style access.

### Taskwarrior sync

Bucket `taskwarrior`, key `taskwarrior-sync`, reached virtual-hosted as
`taskwarrior.garage.f3s.buetow.org`. This is what motivated `root_domain`:
Fedora's stock `task` 3.4.2 has **no** `sync.aws.endpoint_url` or
`sync.aws.force_path_style` key (both landed upstream after v3.5.0), so it
cannot be told to use path-style, and the endpoint has to come from the AWS
SDK's own environment variable.

Credentials and the client-side encryption secret live in
`~/.config/garage/taskwarrior-sync.env` (mode 0600). `~/.taskrc` refers to them
as `$GARAGE_*` / `$TASK_SYNC_SECRET` — taskrc expands environment variables, so
no secret sits in the config file.

```sh
tasksync                      # fish function, dotfiles/fish/conf.d/tasksync.fish
```

or by hand:

```sh
. ~/.config/garage/taskwarrior-sync.env
AWS_ENDPOINT_URL_S3="$GARAGE_ENDPOINT" task sync
```

`AWS_ENDPOINT_URL_S3` must be set **per-invocation, never exported**: a global
value redirects every SDK-based S3 client on the machine at Garage, and
`~/.aws` holds a live `[default]` profile.

Note the objects are opaque to Garage — TaskChampion encrypts client-side, so a
version object fetched straight from the bucket contains no readable task text.

Full background: `conf:f3s/docs/taskwarrior-s3-sync.md`.
