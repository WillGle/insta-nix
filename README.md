# NixOS Flake Configuration (Multi-host)

This repository is organized for:

- Multi-host management
- Safe remote migration
- Minimal complexity (shared base + host overlays)

It keeps backward-compatible flake output naming for the current laptop:

- `Laptop`
- `Laptop-bootstrap`
- `Laptop-dns-canary`

## Current Architecture

```text
/etc/nixos
├── flake.nix
├── flake.lock
├── README.md
├── ATOMIC_NOTE_USAGE.md
├── YAZI_USAGE.md
├── profiles
│   ├── common/
│   ├── roles/
│   └── hardware/
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
- Effective firewall TCP ports (from this repo): `2222`
- Effective firewall UDP ports (from this repo): none by default

### `Laptop-bootstrap` (temporary remote install profile)

- SSH ports: `22`, `2222`
- `PermitRootLogin = "prohibit-password"` (key-based rescue)
- `PasswordAuthentication = false`
- Effective firewall TCP ports (from this repo): `22`, `2222`
- Effective firewall UDP ports (from this repo): none by default

### `Laptop-dns-canary` (safe DNS test profile)

- Same as strict profile for SSH/firewall posture.
- Only DNS delta: `services.resolved.dnsovertls = "opportunistic"`
- Intended for staged DNS testing before changing the daily profile.

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

### Build DNS canary profile

```bash
nixos-rebuild build --flake path:/etc/nixos#Laptop-dns-canary
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
nix eval --json path:/etc/nixos#nixosConfigurations.Laptop.config.networking.firewall.allowedTCPPorts
nix eval --json path:/etc/nixos#nixosConfigurations.\"Laptop-bootstrap\".config.networking.firewall.allowedTCPPorts
nix eval --json path:/etc/nixos#nixosConfigurations.Laptop.config.networking.firewall.allowedUDPPorts
nix eval --json path:/etc/nixos#nixosConfigurations.\"Laptop-bootstrap\".config.networking.firewall.allowedUDPPorts
nix eval --raw path:/etc/nixos#nixosConfigurations.Laptop.config.services.resolved.dnsovertls
nix eval --raw path:/etc/nixos#nixosConfigurations.\"Laptop-dns-canary\".config.services.resolved.dnsovertls
```

### DNS canary rollout (recommended)

```bash
# 1) Non-persistent test (safe): applies until reboot
sudo nixos-rebuild test --flake /etc/nixos#Laptop-dns-canary

# 2) Smoke checks (run with VPN OFF and ON)
resolvectl status
resolvectl query nixos.org openai.com cloudflare.com
dig +short @127.0.0.53 github.com

# 3) If stable, persist canary temporarily
sudo nixos-rebuild switch --flake /etc/nixos#Laptop-dns-canary

# 4) Roll back immediately if DNS degrades
sudo nixos-rebuild switch --rollback
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

## Maintenance

### Update flake inputs

```bash
nix flake update
```

### Garbage collection & Store optimization

```bash
# Delete older generations and optimize the store
sudo nix-collect-garbage -d
nix-store --optimize
```

### Check store for corruption

```bash
nix-store --verify --check-contents
```

## Operational Notes

- If your Git tree has untracked new files, `--flake .#...` may fail because `git+file` flakes only include tracked files.
- Use `path:/etc/nixos#...` during local refactors, or stage files with `git add -A`.
- Host-specific storage for Ryzen14 is defined in `hosts/ryzen14/storage.nix`.
- Wallpaper is now local (`~/.config/hypr/wallpaper.png`) to avoid hard dependency on `/mnt/vault` at session startup.
- Battery reserve mode defaults to `ON` at boot via `battery-reserve-default.service`, using dynamic node discovery under `/sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode`.
- Steam does not auto-open firewall ports; open game ports explicitly in host modules when needed.
- Waybar has a dedicated `battery mode` button between power profile and refresh-rate modules.
- Right-click the `battery mode` button to toggle reserve mode at runtime; `system energy flow` remains read-only monitoring.
