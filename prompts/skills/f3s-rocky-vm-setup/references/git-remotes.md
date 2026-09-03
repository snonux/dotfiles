# Git Remotes on Rocky

Forgejo is the git forge (`code.f3s.buetow.org`). Remotes look like:

```
ssh://git@code.f3s.buetow.org:2022/snonux/REPO.git
```

Server-side account and org write access: see
[`f3s-workloads` Forgejo — rocky push access](../../f3s-workloads/references/forgejo.md#rocky-push-access).

## Forgejo SSH key (paul@rocky)

Passphrase-less key dedicated to Forgejo (do not reuse the host login key):

```sh
ssh-keygen -t ed25519 -N '' \
  -f ~/.ssh/id_ed25519_forgejo \
  -C 'paul@rocky forgejo'
```

Pin it for the forge host in `~/.ssh/config` so git never offers the wrong key:

```
Host code.f3s.buetow.org
  IdentityFile ~/.ssh/id_ed25519_forgejo
  IdentitiesOnly yes
```

Publish the pubkey to the Forgejo user `rocky` (API or web UI) — steps in the
Forgejo reference above. Verify:

```sh
ssh -T -p 2022 git@code.f3s.buetow.org
# Hi there, rocky! You've successfully authenticated with the key named paul@rocky forgejo, ...
```
