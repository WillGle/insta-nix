# Host Onboarding

## Purpose

This guide shows how to add a new host to this repository.

## When to use

Use this guide when creating a new machine entrypoint or checking which modules a host should import.

## Prerequisites

- The new host has a stable host ID.
- You can generate or copy a valid `hardware-configuration.nix`.
- You know whether the host belongs under `hosts/personal/` or `hosts/generic/`.

## Steps

1. Copy the host template.

   ```bash
   cp -r hosts/_template hosts/<host-id>
   ```

2. Fill the host files.

   - `hosts/<host-id>/hardware-configuration.nix`: generated from `nixos-generate-config`
   - `hosts/<host-id>/networking.nix`: hostname and network settings
   - `hosts/<host-id>/home-overlay.nix`: host-specific Home Manager additions

3. Add the host entrypoint in the correct directory.

   - Personal machine: `hosts/personal/`
   - Generic installer or blank profile: `hosts/generic/`

4. Import the modules the host needs.

   Minimum imports:

   - `profiles/shared/base.nix`
   - one user module from `profiles/shared/users-*.nix`

   Add host-specific modules as needed:

   - personal system modules from `profiles/personal/*.nix`
   - host-local networking, storage, or hardware modules
   - Home Manager overlay for desktop hosts

5. Add the output to `flake.nix` under `nixosConfigurations`.

   Example key:

   ```nix
   nixosConfigurations.<HostKey>
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
