# Insta-Nix

A modular, multi-host NixOS & Home Manager Flake configuration.

## Configurations

* **`laptop`** — Primary personal laptop (AMD, Hyprland, Home Manager, local LLMs).
* **`plank`** — Lightweight remote-install & bootstrap target.

## Structure

```text
/etc/nixos/
├── flake.nix                  # Flake inputs & nixosConfigurations entrypoint
├── hosts/                     # Host-specific configurations & assets
│   ├── laptop/         # Main host entrypoint (system.nix, home.nix)
│   └── plank/                 # Remote bootstrap target
├── modules/                   # Modular feature components
│   ├── nixos/                 # System modules (llm, ryzen, desktop-integration)
│   └── home/                  # User modules (screen-time, waybar, hyprland)
├── users/                     # Base user account definitions
└── theme/                     # Dynamic theme templates & engines
```

## Usage

```bash
# Apply system configuration
sudo nixos-rebuild switch --flake /etc/nixos#laptop

# Dry-run build verification
nixos-rebuild dry-build --flake /etc/nixos#laptop
```
