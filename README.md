# NixOS Flake Configuration (Multi-host)

This repository is organized for:

- Multi-host management
- Safe remote migration
- Minimal complexity (shared base + host overlays)

It keeps backward-compatible flake output naming for the current laptop:

- `Laptop`
- `Laptop-bootstrap`

## Current Architecture

```text
/etc/nixos
├── flake.nix
├── profiles
│   ├── common
│   │   ├── core.nix
│   │   ├── i18n.nix
│   │   ├── users-will.nix
│   │   ├── services-base.nix
│   │   ├── connectivity-base.nix
│   │   ├── ssh-strict.nix
│   │   └── ssh-bootstrap.nix
│   ├── roles
│   │   ├── desktop-hypr.nix
│   │   ├── workstation-apps.nix
│   │   └── gaming.nix
│   └── hardware
│       └── amd-ryzen-laptop.nix
├── hosts
│   ├── ryzen14
│   │   ├── default.nix
│   │   ├── hardware-configuration.nix
│   │   ├── storage.nix
│   │   ├── networking.nix
│   │   └── home-overlay.nix
│   └── _template
├── home
│   ├── base.nix
│   └── desktop-common.nix
├── dotfiles
│   ├── common
│   │   ├── fastfetch
│   │   ├── waybar
│   │   └── wofi
│   └── hosts/ryzen14
│       ├── hypr
│       ├── kanshi
│       └── local-bin
└── docs
    ├── HOST_ONBOARDING.md
    └── REMOTE_MIGRATION.md
```

## Composition Model

- `profiles/common/*`: shared baseline, no host identity
- `profiles/hardware/*`: hardware-class tuning, reusable by similar machines
- `profiles/roles/*`: functional stacks (desktop, apps, gaming)
- `hosts/<host>/*`: host identity (hostname, disk UUIDs, host networking, host HM overlay)
- `home/base.nix`: shared Home Manager baseline
- `home/desktop-common.nix`: shared desktop HM layer
- `hosts/<host>/home-overlay.nix`: host-specific HM additions

## Flake Outputs

### `Laptop` (strict daily profile)

- SSH port: `2222`
- `PermitRootLogin = "no"`
- `PasswordAuthentication = false`

### `Laptop-bootstrap` (temporary remote install profile)

- SSH ports: `22`, `2222`
- `PermitRootLogin = "prohibit-password"` (key-based rescue)
- `PasswordAuthentication = false`

## Command Matrix

### Validate flake structure

```bash
nix flake check --no-build --no-write-lock-file path:/etc/nixos
```

### Build strict profile

```bash
nixos-rebuild build --flake path:/etc/nixos#Laptop
```

### Build bootstrap profile

```bash
nixos-rebuild build --flake path:/etc/nixos#Laptop-bootstrap
```

### Apply strict profile

```bash
sudo nixos-rebuild switch --flake /etc/nixos#Laptop
```

### Verify key runtime values

```bash
nix eval --raw path:/etc/nixos#nixosConfigurations.Laptop.config.networking.hostName
nix eval --json path:/etc/nixos#nixosConfigurations.Laptop.config.services.openssh.ports
nix eval --json path:/etc/nixos#nixosConfigurations.\"Laptop-bootstrap\".config.services.openssh.ports
```

### Local lint/format hygiene

```bash
nix shell nixpkgs#statix nixpkgs#deadnix nixpkgs#nixfmt-rfc-style --command bash -lc \
  'statix check . && deadnix . && nixfmt --check flake.nix $(find profiles hosts home -name "*.nix" | sort)'
```

## Remote Migration Flow

1. Boot target machine into NixOS installer with SSH enabled.
2. Install bootstrap output:

```bash
npx nixos-anywhere --flake .#Laptop-bootstrap root@<ip>
```

3. Verify normal user access:

```bash
ssh -p 2222 will@<ip>
```

4. Harden to strict profile:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#Laptop
```

5. Re-verify SSH on `2222`.

See full runbook: `docs/REMOTE_MIGRATION.md`

## Adding a New Host

1. Copy template:

```bash
cp -r hosts/_template hosts/<host-id>
```

2. Fill:
- `hosts/<host-id>/hardware-configuration.nix`
- `hosts/<host-id>/networking.nix`
- `hosts/<host-id>/home-overlay.nix`

3. Register new output(s) in `flake.nix`.
4. Build and validate.

Detailed guide: `docs/HOST_ONBOARDING.md`

## Operational Notes

- If your Git tree has untracked new files, `--flake .#...` may fail because `git+file` flakes only include tracked files.
- Use `path:/etc/nixos#...` during local refactors, or stage files with `git add -A`.
- Host-specific storage for Ryzen14 is defined in `hosts/ryzen14/storage.nix`.
- Wallpaper is now local (`~/.config/hypr/wallpaper.png`) to avoid hard dependency on `/mnt/vault` at session startup.
