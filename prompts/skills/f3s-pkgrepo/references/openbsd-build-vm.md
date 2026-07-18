# OpenBSD Build VM

A minimal OpenBSD QEMU/KVM VM on earth for native compilation of CGo packages (e.g. dtail with DataDog/zstd). Cross-compiling CGo from Linux to OpenBSD needs a C cross-compiler; native build sidesteps that entirely.

Scripts in `~/git/conf/packages/buildvm/`.

## Initial Setup (once)

```sh
cd ~/git/conf/packages/buildvm

# Fetch signify keys from fishfinger
scp rex@fishfinger.buetow.org:/etc/signify/custom-pkg.sec .
scp rex@fishfinger.buetow.org:/etc/signify/custom-pkg.pub .

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

VM specs: headless, SSH on `localhost:2222`, 1 GB RAM, 2 CPUs, 4 GB disk.
Username: `pbuild` (password: `build123`). SSH key installed by `provision.sh`.

Source is synced via `git archive HEAD | ssh ... tar -x` — not `scp -r` — to avoid filling `/tmp` with build artifacts and test data (full repo with benchmarks exceeds the 4 GB disk).

## Installer Notes (install-expect.exp)

- Expect script is a **separate file** to avoid bash/expect quoting interactions — embedding it in a bash heredoc breaks password sends
- Serial console activated via `set tty com0` at the OpenBSD boot prompt
- Password prompts need `sleep 2` before `send` — `sleep 1` is not enough for the serial console
- OpenBSD 7.8 added an "Encrypt the root disk?" prompt before the partition layout
- After CONGRATULATIONS, choose shell (`s`) not reboot — the CD is still attached; configure wheel group via `chroot /mnt`
- Username `build` is rejected ("not a usable loginname") — use `pbuild`
