# NixOS Flake Configuration

This repository contains a small multi-host NixOS flake with a personal laptop profile and a remote-install bootstrap target.

Public documentation in this repo is intentionally limited to structure, workflows, and setup. Sensitive operational notes should stay under `docs/internal/`, which is git-ignored on purpose.

## Outputs

- `think14gryzen`: the main personal laptop with Home Manager enabled
- `plank`: a remote-install bootstrap target

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
├── hosts/
│   ├── _template/
│   ├── plank/
│   └── think14gryzen/
├── modules/
│   ├── home/
│   └── nixos/
├── users/
├── assets/
│   └── common/
├── theme/
└── scripts/
```

Main layout:

- `flake.nix`: declares flake inputs and exported `nixosConfigurations`
- `hosts/`: one directory per host, including host-local Nix modules and host assets
- `modules/nixos/`: reusable NixOS modules such as `base`, `theme`, `roles`, and `ssh`
- `modules/home/`: shared Home Manager modules
- `users/`: shared user base definitions
- `assets/common/`: reusable desktop assets and shared scripts
- `theme/`: generated-theme templates and theme application scripts
- `docs/guides/`: active setup and maintenance guides
- `docs/archive/`: retired or historical notes

## App Scripts In `local-bin`

The user-facing desktop tools in this repo are mostly small shell apps deployed into `~/.local/bin` via Home Manager.

Shared app entrypoints:

- `rofi-show`: open app or window mode through the shared rofi config
- `rofi-clipboard`: clipboard picker backed by `cliphist`
- `theme-lock`: lock-screen wrapper tied to the repo theme

Host-specific app entrypoints for `think14gryzen`:

- `rofi-network`: interactive network menu using `nmcli`
- `rofi-screen-time`: rofi dashboard for app usage stats
- `rofi-study-timer`: rofi UI for building and launching study sessions
- `study-timer`: timer/session backend used by the rofi timer UI
- `atomic-note`: quick task capture and task-list UI for rofi and waybar
- `monitor-setup`: manual monitor layout picker using `hyprctl`
- `waybar-*`: waybar helper scripts for memory, power, network, and refresh status

These are wired in [home.nix](/etc/nixos/hosts/think14gryzen/home.nix) and sourced from:

- `assets/common/rofi/`: core desktop utilities
- `hosts/think14gryzen/assets/rofi/`: host-specific themes
- `hosts/think14gryzen/assets/local-bin/`: host-specific binaries
- `hosts/think14gryzen/assets/rofi-screen-time/`: screen-time suite logic
- `assets/common/waybar/`: shared waybar widgets

## Setup

Validate the flake:

```bash
nix flake check --no-build --no-write-lock-file path:/etc/nixos
```

Build the personal host:

```bash
nixos-rebuild build --flake path:/etc/nixos#think14gryzen
```

Apply the personal host:

```bash
sudo nixos-rebuild switch --flake path:/etc/nixos#think14gryzen
```

Useful rule:

- prefer `path:/etc/nixos#...` over `.#...` when local ignored files exist

## Remote Setup

The remote bootstrap path uses `plank`.

Build it locally:

```bash
nixos-rebuild build --flake path:/etc/nixos#plank
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
