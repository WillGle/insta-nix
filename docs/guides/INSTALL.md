# Install NixOS from an existing Linux

Install NixOS to a whole disk from a running Linux distribution. No USB or
remote SSH install.

## Requirements

- `x86_64`, UEFI, Secure Boot disabled.
- Internet access and `root`/`sudo`.
- The target disk will be **wiped**; no dual boot.
- Prefer Ethernet if the old distro's Wi-Fi firmware is unstable.

## Preflight

```bash
lsblk -d -o NAME,SIZE,MODEL
sudo bash install.sh --dry-run --yes --disk /dev/nvme0n1
```

`--dry-run` does not write to disk. Only run for real when `--disk` points to
the disk you want to erase.

## Install

```bash
curl -fsSLO https://raw.githubusercontent.com/WillGle/insta-nix/main/install.sh
sudo bash install.sh --disk /dev/nvme0n1
sudo reboot
```

The default host is `minimal`:

- Console only; no desktop, no Home Manager.
- No swap, no swapfile.
- NetworkManager and user `will` (member of `wheel` and `networkmanager`).
- Good for older hardware or as a base before choosing a full host.
- The script prompts for `will`'s password after install.

## Options

| Option | Meaning |
|---|---|
| `--host NAME` | Host from the flake (default: `minimal`) |
| `--yes` | Skip the WIPE confirmation |
| `--reboot` | Reboot immediately when done |
| `--dry-run` | Print the plan without touching the disk |

Example: install the full laptop host:

```bash
sudo bash install.sh --disk /dev/nvme0n1 --host laptop
```

The installer generates a new `hardware.nix` from the actual hardware. For
`laptop`, this replaces the current hardware policy in the temporary
checkout; only use it if you accept that.

## What the script does

1. Check root, UEFI, `x86_64`, disk, and network.
2. Confirm the disk wipe.
3. Install Nix if missing.
4. Download the repo from GitHub to a temporary directory.
5. `disko`: create GPT, a 512M ESP, and an ext4 root; mount at `/mnt`.
6. `nixos-generate-config`: create the real hardware config.
7. `nixos-install --flake <repo>#<host>`.
8. Set the password for `will`.
9. Copy the repo and hardware config to `/mnt/etc/nixos`.

After reboot, rebuild from `/etc/nixos`:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#minimal
```

`/etc/nixos` is a source copy from the tarball, not a Git checkout. To use Git,
clone the repo elsewhere and point `--flake` there.

## Troubleshooting

- `404` downloading `install.sh`: the commit has not been pushed to `main`.
- `not a whole disk` / `has mounted partitions`: check `lsblk`, unmount, or
  choose the correct disk.
- `UEFI is required`: the machine booted in legacy/BIOS mode; boot in UEFI.
- `nix: command not found`: open a new shell or source
  `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`.
- Secure Boot enabled: disable it first; systemd-boot is not signed.
- Test in a UEFI VM or on a spare disk before running on real hardware.

## Limits

- UEFI only; BIOS/legacy is not supported.
- No disk encryption.
- No swap.
- The `minimal` host does not enable SSH by default.
- Always check `--disk` before running; the script wipes the whole disk.
