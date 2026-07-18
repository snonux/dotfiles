# Git Remotes on Rocky

All repos available on the local git server have `r0`, `r1`, `r2` remotes replacing any codeberg ones:

```
url = ssh://git@r0:30022/repos/REPO.git
url = ssh://git@r1:30022/repos/REPO.git
url = ssh://git@r2:30022/repos/REPO.git
```

Repos pushed: conf, dotfiles, gemtexter, gitsyncer, goprecords, gt, hexai, hypr, ior, photoalbum, rcm, snonux, tasksamurai, wireguardmeshgenerator

The public keys of both `root` and `paul` on rocky are in the k3s `git-server-authorized-keys` secret (namespace `cicd`).
