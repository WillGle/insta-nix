# Host Onboarding

This repository uses a hard-migrated taxonomy:

- `hosts/personal/*`: personal machine definitions
- `hosts/generic/*`: generic/blank installer-style definitions
- `profiles/shared/*`: shared baseline modules
- `profiles/personal/*`: personal machine stacks
- `home/*`: shared Home Manager modules

## Add a new host

1. Copy template:

```bash
cp -r hosts/_template hosts/<host-id>
```

2. Fill host files:

- `hosts/<host-id>/hardware-configuration.nix` from `nixos-generate-config`
- `hosts/<host-id>/networking.nix` with hostname and host firewall interfaces
- `hosts/<host-id>/home-overlay.nix` for host-specific dotfiles/scripts

3. Pick taxonomy bucket:

- Personal machine: place entrypoint under `hosts/personal/`
- Generic/blank profile: place entrypoint under `hosts/generic/`

4. Wire profile stack:

- Always include shared baseline from `profiles/shared/base.nix`
- Add user policy module (`profiles/shared/users-*.nix`)
- Add personal system stack when needed (`profiles/personal/*.nix`)

5. Add flake output in `flake.nix`:

- `nixosConfigurations.<HostKey>`

6. Validate:

```bash
nix flake check --no-build --no-write-lock-file path:/etc/nixos
nixos-rebuild build --flake path:/etc/nixos#<HostKey>
```

For generic remote-install host patterns and local-private key handling, see:

- [`PLANK_REMOTE_INSTALL.md`](./PLANK_REMOTE_INSTALL.md)
