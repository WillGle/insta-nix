# Host Onboarding

This repository uses a multi-host layout:

- `profiles/common`: shared baseline
- `profiles/roles`: feature roles (desktop, apps, gaming)
- `profiles/hardware`: hardware-class tuning
- `hosts/<host>`: host-specific hardware/network/storage/home overlay
- `home`: shared Home Manager base modules

## Add a new host

1. Copy template:

```bash
cp -r hosts/_template hosts/<host-id>
```

2. Fill host files:

- `hosts/<host-id>/hardware-configuration.nix` from `nixos-generate-config`
- `hosts/<host-id>/networking.nix` with hostname and host firewall interfaces
- `hosts/<host-id>/home-overlay.nix` for host-specific dotfiles/scripts

3. Add a host module file (optional if template default is enough):

- `hosts/<host-id>/default.nix` imports host + profiles modules

4. Add flake output in `flake.nix`:

- `nixosConfigurations.<HostKey>` (strict SSH)
- optionally `nixosConfigurations.<HostKey>-bootstrap`

5. Validate:

```bash
nix flake check --no-build
nixos-rebuild build --flake .#<HostKey>
```
