# Plank Remote Install

## Purpose

This guide explains how to install `plank` on a remote machine without `disko`.

## When to use

Use this guide for new remote installs that should boot into the bootstrap installer configuration.

## Prerequisites

- You can build `plank` from this repo.
- The target machine is booted into a NixOS installer environment.
- You can reach the target over the network.
- The required Plank SSH public-key seed exists at
  `/etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys`.

## Steps

1. Run the required checks.

   ```bash
   nix flake check --no-build --no-write-lock-file path:/etc/nixos
   nixos-rebuild build --flake path:/etc/nixos#plank
   ```

2. Prepare the required disk labels on the target.

   Required labels:

   - `NIXOS_BOOT` for `/boot`
   - `NIXOS_ROOT` for `/`
   - `NIXOS_SWAP` for swap

   Example:

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

3. Prepare the required SSH public-key seed and any optional local-private files.

   The seed is mandatory for the first install:

   - `/etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys`

   Validate it before copying:

   ```bash
   test -s /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys
   ssh-keygen -l -f /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys
   ```

   Other optional paths:

   - `/etc/nixos/.local/remote-install/keys/plank-authorized_keys`
   - `/etc/nixos/.local/remote-install/seed/home/<user>/.ssh/authorized_keys`
   - `/etc/nixos/.local/remote-install/hardware/`
   - `/etc/nixos/.local/remote-install/runbooks/`
   - `/etc/nixos/.local/remote-install/modules/plank-host-local.nix`

4. Choose one install method.

   Local clone source:

   ```bash
   rsync -a --delete /etc/nixos/ root@<ip>:/mnt/etc/nixos/
   ssh root@<ip> 'install -d -m 700 /mnt/etc/plank'
   scp /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys \
     root@<ip>:/mnt/etc/plank/authorized_keys
   ssh root@<ip> '
     test -s /mnt/etc/plank/authorized_keys &&
     ssh-keygen -l -f /mnt/etc/plank/authorized_keys &&
     nixos-install --root /mnt --flake path:/mnt/etc/nixos#plank
   '
   ```

   GitHub source:

   ```bash
   ssh root@<ip> 'install -d -m 700 /mnt/etc/plank'
   scp /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys \
     root@<ip>:/mnt/etc/plank/authorized_keys
   ssh root@<ip> '
     test -s /mnt/etc/plank/authorized_keys &&
     ssh-keygen -l -f /mnt/etc/plank/authorized_keys &&
     nixos-install --root /mnt --flake github:<owner>/<repo>#plank
   '
   ```

## Verification

Check access:

```bash
ssh -p 2222 <user>@<ip>
```

Confirm that local-private files are still outside the tracked repo:

```bash
git -C /etc/nixos status --ignored --short
git -C /etc/nixos ls-files | rg -n "remote-install|authorized_keys|\\.local"
```

## Related docs

- [`HOST_ONBOARDING.md`](./HOST_ONBOARDING.md)
- [`../README.md`](../README.md)
