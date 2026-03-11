# Plank Remote Install (Public Guide, No Disko)

`generic-installer` is a no-disko generic installer profile.

Key policy:

- No secrets/keys are stored in this public repository.
- Local-private files are expected under `/etc/nixos/.local/remote-install/` (ignored by git).
- SSH for `generic-installer` is strict: key-based only, non-root, port `2222`.

## Guardrail Checks (required)

```bash
nix flake check --no-build --no-write-lock-file path:/etc/nixos
nixos-rebuild build --flake path:/etc/nixos#generic-installer
```

## Disk Layout Contract (required)

`generic-installer` expects these labels:

- `NIXOS_BOOT` (vfat, mounted at `/boot`)
- `NIXOS_ROOT` (ext4, mounted at `/`)
- `NIXOS_SWAP` (swap)

Example on target installer shell (adjust disk path):

```bash
DISK=/dev/nvme0n1
parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart SWAP linux-swap 1025MiB 17409MiB
parted -s "$DISK" -- mkpart ROOT ext4 17409MiB 100%

mkfs.vfat -F32 -n NIXOS_BOOT "${DISK}p1"
mkswap -L NIXOS_SWAP "${DISK}p2"
mkfs.ext4 -L NIXOS_ROOT "${DISK}p3"

mount /dev/disk/by-label/NIXOS_ROOT /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/NIXOS_BOOT /mnt/boot
swapon /dev/disk/by-label/NIXOS_SWAP
```

## Local-Private Directory Layout

Create and populate:

- `/etc/nixos/.local/remote-install/keys/plank-authorized_keys`
- `/etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys`
- `/etc/nixos/.local/remote-install/seed/home/will/.ssh/authorized_keys`
- `/etc/nixos/.local/remote-install/hardware/`
- `/etc/nixos/.local/remote-install/runbooks/`
- `/etc/nixos/.local/remote-install/modules/plank-host-local.nix` (optional; auto-imported by `hosts/generic/plank.nix`)

## Mode 1: Local Clone Source (recommended)

From Ryzen, after target disk is mounted at `/mnt`:

```bash
rsync -a --delete /etc/nixos/ root@<ip>:/mnt/etc/nixos/
scp /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys \
  root@<ip>:/mnt/etc/plank/authorized_keys
ssh root@<ip> 'nixos-install --root /mnt --flake path:/mnt/etc/nixos#generic-installer'
```

## Mode 2: GitHub-Direct Source

Keep repo source public, but inject key from local-private storage:

```bash
scp /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys \
  root@<ip>:/mnt/etc/plank/authorized_keys
ssh root@<ip> 'nixos-install --root /mnt --flake github:WillGle/insta-nix#generic-installer'
```

If key injection is unavailable, use a temporary manual key in installer environment,
then reconcile after first successful login.

## Post-Install Verification

```bash
ssh -p 2222 will@<ip>
```

Confirm public repo still clean:

```bash
git -C /etc/nixos status --ignored --short
git -C /etc/nixos ls-files | rg -n "remote-install|authorized_keys|\\.local"
```
