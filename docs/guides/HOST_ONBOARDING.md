# Host Onboarding

## Purpose

This guide shows how to add a new host to this repository.

## When to use

Use this guide when creating a new machine entrypoint or checking which modules a host should import.

## Prerequisites

- The new host has a stable host ID.
- You can generate or copy a valid hardware module.

## Steps

1. Copy the host template.

   ```bash
   cp -r hosts/_template hosts/<host-id>
   ```

2. Fill the host files.

   - `hosts/<host-id>/hardware.nix`: generated from `nixos-generate-config`
   - `hosts/<host-id>/network.nix`: hostname and network settings
   - `hosts/<host-id>/storage.nix`: host-local filesystems, swap, or automounts
   - `hosts/<host-id>/system.nix`: host-specific services, packages, and policy
   - `hosts/<host-id>/home.nix`: host-specific Home Manager additions for desktop hosts
   - `hosts/<host-id>/assets/`: host-specific scripts and config assets deployed by Home Manager

3. Wire the host entrypoint in `hosts/<host-id>/default.nix`.

   Minimum imports:

   - `../../modules/nixos/base.nix`
   - `../../users/will.nix`
   - host-local modules such as `./hardware.nix`, `./storage.nix`, `./network.nix`, and `./system.nix`

4. Import any reusable role modules the host needs.

   Common examples:

   - `../../modules/nixos/roles/iac.nix`
   - `../../modules/nixos/roles/kubernetes.nix`
   - `../../modules/nixos/ssh/strict.nix`
   - `../../modules/nixos/ssh/plank.nix`

5. Add the output to `flake.nix` under `nixosConfigurations`.

   Example key:

   ```nix
   nixosConfigurations.<host-id>
   ```

## Verification

Run:

```bash
nix flake check --no-build --no-write-lock-file path:/etc/nixos
nixos-rebuild build --flake path:/etc/nixos#<HostKey>
```

## Related docs

- [`PLANK_REMOTE_INSTALL.md`](./PLANK_REMOTE_INSTALL.md)
- [`../README.md`](../README.md)
