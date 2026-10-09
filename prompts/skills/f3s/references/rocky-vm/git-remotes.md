# Git Remotes on Rocky

Forgejo is the git forge (`code.f3s.buetow.org`). Remotes look like:

```
ssh://git@code.f3s.buetow.org:2022/snonux/REPO.git
```

Server-side account and org write access: see
[Workloads — Forgejo, rocky push access](../workloads/forgejo.md#rocky-push-access).

## Forgejo SSH key (paul@rocky)

Passphrase-less key dedicated to Forgejo (do not reuse the host login key):

```sh
ssh-keygen -t ed25519 -N '' \
  -f ~/.ssh/id_ed25519_forgejo \
  -C 'paul@rocky forgejo'
```

The pin lives in the shared dotfiles `ssh/config` (deployed by gonf `home_ssh`),
guarded so it only applies on hosts that have the key — do **not** hand-edit
`~/.ssh/config` on rocky, the next `home_ssh` deploy overwrites it:

```
Match host code.f3s.buetow.org exec "test -f %d/.ssh/id_ed25519_forgejo"
IdentityFile ~/.ssh/id_ed25519_forgejo
IdentitiesOnly yes
```

It must stay above `Host *.buetow.org`. Symptom when missing: `Permission
denied (publickey)` on clone, because ssh only offers `id_rsa`/`id_ed25519`.

Publish the pubkey to the Forgejo user `rocky` (API or web UI) — steps in the
Forgejo reference above. Verify:

```sh
ssh -T -p 2022 git@code.f3s.buetow.org
# Hi there, rocky! You've successfully authenticated with the key named paul@rocky forgejo, ...
```
