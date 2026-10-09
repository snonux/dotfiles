# Garage: useful commands, access keys and buckets

## Useful Commands

### Cluster health

```sh
ssh -p 22 paul@f0.lan.buetow.org 'doas garage status'
ssh -p 22 paul@f0.lan.buetow.org 'doas garage stats -a'
```

### Local S3 check (no public endpoint)

```sh
ssh -p 22 paul@f0.lan.buetow.org 'curl -sS -o /dev/null -w "%{http_code}\n" http://localhost:3900/'
```

### External endpoint checks

```sh
# Anonymous check should return 403 AccessDenied XML (expected)
ssh rex@fishfinger.buetow.org 'curl -sS -D - https://garage.f3s.buetow.org/ | sed -n "1,20p"'

# Reachability from edge hosts to Garage WG backends
ssh rex@fishfinger.buetow.org 'for ip in 192.168.2.130 192.168.2.131 192.168.2.132; do nc -zvw2 $ip 3900; done'
ssh rex@blowfish.buetow.org 'for ip in 192.168.2.130 192.168.2.131 192.168.2.132; do nc -zvw2 $ip 3900; done'
```

### Creating an access key and granting it a bucket

```sh
ssh paul@f0.lan.buetow.org 'doas garage key create <alias>'
ssh paul@f0.lan.buetow.org 'doas garage bucket allow --read --write --owner <bucket> --key <alias>'
```

`--owner` also lets the key manage the bucket itself; drop it for a plain
read/write consumer. To read a secret back later — it is stored, so this is
recovery, not re-issue:

```sh
ssh paul@f0.lan.buetow.org 'doas garage key info <alias> --show-secret'
ssh paul@f0.lan.buetow.org 'doas garage key list'
ssh paul@f0.lan.buetow.org 'doas garage bucket info <bucket>'   # which keys have access
```

Rotating a key is delete-then-create-then-allow, and is harmless — the data is
untouched:

```sh
ssh paul@f0.lan.buetow.org 'doas garage key delete <alias> --yes'
```

### Client credentials file

Clients that need Garage credentials read them from a file outside any
repository. For Taskwarrior that is `~/.config/garage/taskwarrior-sync.env`,
mode `0600` in a `0700` directory. Format:

```sh
: "${GARAGE_ENDPOINT:=https://garage.f3s.buetow.org}"
export GARAGE_ENDPOINT
: "${GARAGE_REGION:=garage}"
export GARAGE_REGION
: "${GARAGE_BUCKET:=taskwarrior}"
export GARAGE_BUCKET
: "${GARAGE_ACCESS_KEY_ID:=GK...}"
export GARAGE_ACCESS_KEY_ID
: "${GARAGE_SECRET_ACCESS_KEY:=...}"
export GARAGE_SECRET_ACCESS_KEY
: "${TASK_SYNC_SECRET:=...}"
export TASK_SYNC_SECRET
```

Assign with `: "${VAR:=default}"` plus `export`, **not** a plain `export VAR=`.
A plain assignment overwrites whatever the caller already set, which silently
defeats a one-off override such as
`GARAGE_ENDPOINT=http://192.168.1.130:3900 tasksync` — it appears to work while
still using the file's endpoint. That bug was real.

The file is sh syntax, so fish cannot source it; `tasksync` reads the values out
of a subshell with `printenv`. Anything parsing it in Python must handle the
`: "${VAR:=value}"` form, not just `export VAR=value`.

### Restoring that file if it is lost

Four of the six values are trivially recoverable, one is fixed, and **one is
not recoverable at all**.

| Value | How to get it back |
|---|---|
| `GARAGE_ENDPOINT` | `https://garage.f3s.buetow.org` |
| `GARAGE_REGION` | `garage` (the `s3_region` in `garage.toml.tmpl`) |
| `GARAGE_BUCKET` | `doas garage bucket list` |
| `GARAGE_ACCESS_KEY_ID` | `doas garage key list` |
| `GARAGE_SECRET_ACCESS_KEY` | `doas garage key info <alias> --show-secret` |
| **`TASK_SYNC_SECRET`** | **nowhere — see below** |

**Re-issuing credentials in Garage does not help with the last row.** It is the
natural assumption — the S3 access key and secret genuinely can be thrown away
and recreated at will, because Garage stores them. The encryption secret is a
different kind of thing: it never leaves the client, so there is nothing on the
cluster to re-issue. New credentials give you access to the bucket again; they
do not make its contents readable.

`TASK_SYNC_SECRET` is TaskChampion's client-side encryption key. Garage never
receives it and cannot be asked for it: the bucket holds ciphertext only, which
is exactly the point. If every copy is lost, **everything already in the bucket
is permanently unreadable** — the only recovery is to empty the bucket
(`just clean-bucket`, or delete the objects) and re-seed it from a replica that
still holds the tasks locally.

It currently exists in two places, neither of them a repository:

- `~/.config/garage/taskwarrior-sync.env` on the laptop
- `~/Notes/TaskwarriorPhoneSync.md`, which Syncthing replicates to f3s and the
  phone — so that copy doubles as the off-machine backup

Any new replica must use the **same** value; a different one does not error, it
just cannot read what is there.

### Bucket aliases

A bucket can answer to more than one global name, which matters because with
virtual-hosted addressing the bucket name *is* part of the DNS name:

```sh
doas garage bucket alias   <existing-bucket> <new-name>
doas garage bucket unalias <name>
```

Renaming is therefore add-alias-then-remove-old, with no data movement.

### Bucket and key workflow

```sh
ssh -p 22 paul@f0.lan.buetow.org 'doas garage bucket create <bucket>'
ssh -p 22 paul@f0.lan.buetow.org 'doas garage key create <key-alias>'
ssh -p 22 paul@f0.lan.buetow.org 'doas garage bucket allow <bucket> --read --write --key <key-alias>'
ssh -p 22 paul@f0.lan.buetow.org 'doas garage key info <key-alias>'
```

### Authenticated S3 test via external hostname

```sh
ssh -p 22 paul@f0.lan.buetow.org '
TMP=$(mktemp)
doas garage key info watchos-key --show-secret > "$TMP"
AK=$(awk -F": " "/Key ID:/ {print \$2}" "$TMP" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
SK=$(awk -F": " "/Secret key:/ {print \$2}" "$TMP" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
OBJ="e2e-external-$(date +%s).txt"
echo "ok" >/tmp/$OBJ
AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_DEFAULT_REGION=garage \
  aws --endpoint-url https://garage.f3s.buetow.org s3 cp /tmp/$OBJ s3://watchos-app/$OBJ
AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_DEFAULT_REGION=garage \
  aws --endpoint-url https://garage.f3s.buetow.org s3 ls s3://watchos-app/$OBJ
rm -f "$TMP" /tmp/$OBJ
'
```
