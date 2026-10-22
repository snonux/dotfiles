# OpenBSD Build VM

A minimal OpenBSD QEMU/KVM VM on earth for native compilation of CGo packages (e.g. dtail with DataDog/zstd). Cross-compiling CGo from Linux to OpenBSD needs a C cross-compiler; native build sidesteps that entirely.

Scripts in `~/git/conf/packages/buildvm/`.

## Initial Setup (once)

```sh
cd ~/git/conf/packages/buildvm

# Restore private custody from foostore on earth, following
# ~/git/conf/packages/keys/README.md; never retrieve keys from frontends/NFS.
# Verify the VM host key at its console and enroll it in known_hosts
# before provisioning (StrictHostKeyChecking=yes).

./setup.sh       # downloads ISO, runs fully automated install (~5 min)
./provision.sh   # installs Go, git, gmake, signify keys, SSH keys
```

`setup.sh` is fully automated via `install-expect.exp` — drives the OpenBSD serial console installer without manual interaction.

## Day-to-Day Use

```sh
make buildvm-start   # boot VM (~15s)
make dtail-openbsd   # auto-starts VM if needed, then builds
make buildvm-stop    # shut down when done
```

VM specs: headless, SSH forwarded on **127.0.0.1:2222 only**, 1 GB RAM, 2 CPUs, 4 GB disk. An older running VM must be restarted after approval to pick up the loopback binding.
Username: `pbuild` (bootstrap password: `build123`). SSH key installed by `provision.sh`; the local VM is a trusted signing boundary and must never expose this bootstrap login to the LAN.

Source is synced via `git archive HEAD | ssh ... tar -x` — not `scp -r` — to avoid filling `/tmp` with build artifacts and test data (full repo with benchmarks exceeds the 4 GB disk).

## Installer Notes (install-expect.exp)

- Expect script is a **separate file** to avoid bash/expect quoting interactions — embedding it in a bash heredoc breaks password sends
- Serial console activated via `set tty com0` at the OpenBSD boot prompt
- Password prompts need `sleep 2` before `send` — `sleep 1` is not enough for the serial console
- OpenBSD 7.8 added an "Encrypt the root disk?" prompt before the partition layout
- The VM runs the frontends' release (7.9 since 2026-09-26, `OBSD_VERSION` in
  `setup.sh`). For a new release: move `openbsd-build.qcow2` aside until the new
  release's packages are verified, then delete it (the 7.8 disk was removed
  2026-09-26), bump `OBSD_VERSION`, rerun
  `setup.sh` + `provision.sh` (the 7.9 install ran unattended unchanged)
- After CONGRATULATIONS, choose shell (`s`) not reboot — the CD is still attached; configure wheel group via `chroot /mnt`
- Username `build` is rejected ("not a usable loginname") — use `pbuild`

## Signing custody

Both pure-Go OpenBSD packaging and DTail packaging/signing run here, then
standalone `signify -Vz -p /etc/signify/custom-pkg.pub -x "$artifact"
>/dev/null` verifies the complete compressed artifact against the pinned key
before upload. `pkg_info -C` is informational only. Missing
keys fail the build. `install-signing-key.sh` installs the existing signify
identity from earth's private custody and the public half committed under
`packages/keys/`; it checks local privacy, uses verified SSH stdin, stages only
in root-owned `/etc/signify`, and refuses to replace different existing keys.
It can run independently of full provisioning, after explicit live approval.

No frontend is a private-key source. The 2026-10-22 local preparation created
foostore recovery backups but did not change any VM or frontend. Approve the
restart/provision/signature smoke test and subsequent removal of approved
historical frontend/NFS key copies as one live migration. See
`~/git/conf/packages/keys/README.md` for exact references and recovery steps.

### Disk, SSH and backup custody gates (2026-10-22)

The VM disk must be an operator-owned regular non-symlink, mode 0600. Setup,
start, direct expect installation and signing-key installation enforce this;
the existing stopped disk was corrected locally to 0600. Bootstrap pbuild
password authentication must be disabled before key transfer: password and
keyboard-interactive off, root SSH off, AuthenticationMethods publickey, and
UseDNS no. The installer verifies a fresh key login, global/Match-effective
settings and active-daemon method advertisements; a missing reload fails.
Follow the exact two-session hardening/recovery sequence in conf
`packages/keys/README.md` only after explicit live approval. No VM SSH setting
was changed in local preparation.

The full original `/data/nfs` filename scan completed and found a retained
0644 private copy at f0
`/data/nfs/earthdata/backups/earthhome/git/conf/packages/buildvm/custom-pkg.sec`.
It remains pending approved cleanup alongside fishfinger's private key. The
current installed earth home-backup targets f2's encrypted earth-backup;
`/git/` already excludes the legacy checkout key/disk. A targeted
`f3s-package-signing/` exclusion now prevents raw new custody/GnuPG backups,
with receiver protection preserving existing copies for approved cleanup.
No backup was run. Inventory current backups, replicas and retained snapshots;
removing one active file cannot establish retirement of historical exposure.
Signify trust rotation remains a separate reviewed operation.

Native artifact acceptance is still unrun while the VM is stopped: a valid
package must pass standalone pinned-key verification; unsigned, wrong-signer
and late-stream corruption (after 64 KiB compressed data) must fail before
upload. Offline test doubles only establish command/failure propagation.
