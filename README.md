# Insta-Nix

Modular NixOS configuration for a personal laptop and a minimal UEFI install
target.

## Outputs

- `laptop`: AMD laptop with Hyprland, Home Manager, local LLM
  tools, Waybar, and the Rofi utilities.
- `minimal`: Minimal console system for fresh UEFI installs and older hardware.

Inspect the available outputs:

```bash
nix flake show --no-write-lock-file git+file:///etc/nixos
```

## Install from an existing Linux

This wipes the target disk. UEFI x86_64 only; no swap is created.

```bash
curl -fsSLO https://raw.githubusercontent.com/WillGle/insta-nix/main/install.sh
sudo bash install.sh --disk /dev/nvme0n1
sudo reboot
```

The default host is `minimal`: console NixOS, NetworkManager, user `will`, no
desktop and no Home Manager. See
[`docs/guides/INSTALL.md`](./docs/guides/INSTALL.md) for options and details.

## Quick start

Validate and build the laptop configuration:

```bash
make check
make build
```

The equivalent raw commands are:

```bash
./scripts/validate.sh
nix build --no-link --no-write-lock-file \
  git+file:///etc/nixos#nixosConfigurations.laptop.config.system.build.toplevel
```

`make` wraps `check`, `build`, `switch`, `diff`, `update`, and `clean`. `scripts/validate.sh` runs `git diff --check` and `nix flake check`,
which enforces formatting, statix, deadnix, and shellcheck. To run the same gate
before every commit:

```bash
git config core.hooksPath .githooks
```

Apply it only after the check and build succeed:

```bash
sudo nixos-rebuild switch --flake git+file:///etc/nixos#laptop
```

After activation, verify the affected system and user services. A successful
check or build does not prove that the new generation is active.

## Layout

```text
/etc/nixos/
├── flake.nix              # Flake inputs and host outputs
├── Makefile               # check/build/switch/diff/update/clean
├── install.sh             # Local UEFI installer for an existing Linux
├── install/disko.nix      # Installer disk layout
├── base/                  # Shared headless NixOS baseline
├── hosts/
│   ├── minimal/           # Minimal console host for fresh installs
│   └── laptop/     # Laptop identity, hardware, composition
├── modules/
│   ├── cli/               # Home Manager: shell, terminal, XDG
│   ├── desktop/           # NixOS desktop platform + graphical feature slices
│   └── system/            # NixOS roles: hardware, ssh, development, maintenance,
│                          # power, llm, gaming
├── users/will/            # Account, Home Manager identity, personal applications
├── pkgs/                  # Custom packages and their patches
├── lib/                   # Shared Nix helpers
├── scripts/               # Validation and hardware benchmarks
└── docs/                  # Guides and archived notes
```

Each host composes shared features in `hosts/<host>/default.nix` and selects
the desktop suite once in `hosts/<host>/home.nix`. The shared `base/` is
headless. Desktop assets live beside their consuming module under
`modules/desktop/<feature>/`; system role assets live under
`modules/system/<role>/`.

`users/will/packages.nix` is a Home Manager module and owns personal application
selection in the user profile. Genuinely system-wide tools and desktop
integration remain in `environment.systemPackages` under
`hosts/<host>/packages.nix`. Custom package definitions and patches live
together in `pkgs/<package>/`.

Git flake commands include tracked working-tree changes. Add intended new source
files with `git add <paths>` before validation so Nix can see them. Keep local
state and credentials outside the Git source.

## Ownership

One runtime path has one canonical owner:

- NixOS owns system packages, services, hardware, `/etc`, and system-wide
  environment.
- Home Manager owns user packages, shell/XDG configuration, and user services.
- Theme templates are source inputs; `~/.config/theme/generated/` is generated
  runtime output and should not be edited directly.
- Pi, Zed, VS Code, and other unreferenced application settings remain external
  user-owned state.

## Main tools

- Local LLM: `llmfit`, `llm-pull`, `llm-list`, and `llm-fit`.
- Power: `native-power-profile` and `toggle-battery-reserve`.
- Desktop: `rofi-screen-time`, `waybar-*`, and Hyprland helper scripts.
- Wallpaper: Nautilus **Set as Background**, `wallpaper pick`, or `wallpaper set <image>`.
  The GTK Wallpaper portal writes `~/.config/background`; Home Manager's
  `wallpaper-portal.path` detects each replacement and calls `wallpaper set`.
  Matugen generates the palette, and Hyprpaper displays the image. The selected
  image is copied to `~/.local/state/theme/wallpapers/` and survives rebuilds.
  `modules/desktop/theme/scripts/` and `modules/desktop/theme/templates/` own
  this flow; the former Nautilus **Scripts > Set as Wallpaper** entry is retired.
  SDDM keeps its separate image.

## Guides

- [`docs/README.md`](./docs/README.md): documentation index.
- [`docs/guides/HOST_ONBOARDING.md`](./docs/guides/HOST_ONBOARDING.md): add a host.
- [`docs/guides/LOCAL_LLM.md`](./docs/guides/LOCAL_LLM.md): local LLM workflow.
- [`docs/guides/INSTALL.md`](./docs/guides/INSTALL.md): local UEFI installation.
- [`docs/guides/HARDWARE_BENCHMARK.md`](./docs/guides/HARDWARE_BENCHMARK.md): repeatable benchmarks.
