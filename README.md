# NixOS Flake Configuration

This repository contains a small multi-host NixOS flake with a personal laptop profile and a generic remote-install target.

Public documentation in this repo is intentionally limited to structure, workflows, and setup. Sensitive operational notes should stay under `docs/internal/`, which is git-ignored on purpose.

## Outputs

- `Think14GRyzen`: the main personal laptop with Home Manager enabled
- `PlankGeneric`: a generic remote-install target used as a bootstrap system

List them locally with:

```bash
nix flake show --no-write-lock-file path:/etc/nixos
```

## Repository Structure

```text
/etc/nixos
├── flake.nix
├── README.md
├── docs/
│   ├── README.md
│   ├── guides/
│   └── archive/
├── hosts/
├── profiles/
├── home/
├── dotfiles/
│   ├── common/
│   └── hosts/
├── theme/
└── scripts/
```

Main layout:

- `flake.nix`: declares flake inputs and exported `nixosConfigurations`
- `hosts/`: host entry modules and host-local Nix overlays
- `profiles/`: reusable NixOS modules split into shared and personal layers
- `home/`: shared Home Manager modules
- `dotfiles/common/`: reusable desktop assets and shared scripts
- `dotfiles/hosts/<host>/`: host-specific desktop configs and scripts
- `theme/`: generated-theme templates and theme application scripts
- `docs/guides/`: active setup and maintenance guides
- `docs/archive/`: retired or historical notes

## App Scripts In `local-bin`

The user-facing desktop tools in this repo are mostly small shell apps deployed into `~/.local/bin` via Home Manager.

Shared app entrypoints:

- `rofi-show`: open app or window mode through the shared rofi config
- `rofi-clipboard`: clipboard picker backed by `cliphist`
- `theme-lock`: lock-screen wrapper tied to the repo theme

Host-specific app entrypoints for `Think14GRyzen`:

- `rofi-network`: interactive network menu using `nmcli`
- `rofi-screen-time`: rofi dashboard for app usage stats
- `rofi-study-timer`: rofi UI for building and launching study sessions
- `study-timer`: timer/session backend used by the rofi timer UI
- `atomic-note`: quick task capture and task-list UI for rofi and waybar
- `monitor-setup`: manual monitor layout picker using `hyprctl`
- `waybar-*`: waybar helper scripts for memory, power, network, and refresh status

These are wired in [hosts/personal/think14gryzen-home.nix](./hosts/personal/think14gryzen-home.nix) and sourced from:

- `dotfiles/common/rofi/`: core desktop utilities
- `dotfiles/hosts/ryzen14/rofi/`: host-specific themes
- `dotfiles/hosts/ryzen14/local-bin/`: host-specific binaries
- `dotfiles/hosts/ryzen14/rofi-screen-time/`: screen-time suite logic
- `dotfiles/common/waybar/`: shared waybar widgets

## Setup

Validate the flake:

```bash
nix flake check --no-build --no-write-lock-file path:/etc/nixos
```

Build the personal host:

```bash
nixos-rebuild build --flake path:/etc/nixos#Think14GRyzen
```

Apply the personal host:

```bash
sudo nixos-rebuild switch --flake path:/etc/nixos#Think14GRyzen
```

Useful rule:

- prefer `path:/etc/nixos#...` over `.#...` when local ignored files exist

## Remote Setup

The remote bootstrap path uses `PlankGeneric`.

Build it locally:

```bash
nixos-rebuild build --flake path:/etc/nixos#PlankGeneric
```

Then follow the dedicated guide:

- [`docs/guides/PLANK_REMOTE_INSTALL.md`](./docs/guides/PLANK_REMOTE_INSTALL.md)

That guide covers:

- target disk labels
- installer-side flake install flow
- local clone vs GitHub source installs
- verification after first boot

## Documentation Map

- [`docs/README.md`](./docs/README.md): index for tracked documentation
- [`docs/guides/HOST_ONBOARDING.md`](./docs/guides/HOST_ONBOARDING.md): add a new host
- [`docs/guides/PLANK_REMOTE_INSTALL.md`](./docs/guides/PLANK_REMOTE_INSTALL.md): remote install workflow
- [`docs/guides/AMD_PERF_SUITE.md`](./docs/guides/AMD_PERF_SUITE.md): optional AMD performance workflow
- [`docs/guides/LOCAL_LLM.md`](./docs/guides/LOCAL_LLM.md): local LLM notes

Private operational notes belong under `docs/internal/` and are not tracked by git.
