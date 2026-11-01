# Insta-Nix

Modular NixOS configuration for a personal laptop and a lightweight remote
bootstrap target.

## Outputs

- `think14gryzen`: Ryzen 780M laptop with Hyprland, Home Manager, local LLM
  tools, Waybar, and the Rofi utilities.
- `plank`: Minimal headless/remote-install target. It does not use Home Manager.

Inspect the available outputs:

```bash
nix flake show --no-write-lock-file git+file:///etc/nixos
```

## Quick start

Validate and build the laptop configuration:

```bash
nix flake check --no-build --no-write-lock-file git+file:///etc/nixos
nix build --no-link --no-write-lock-file \
  git+file:///etc/nixos#nixosConfigurations.think14gryzen.config.system.build.toplevel
```

Apply it only after the check and build succeed:

```bash
sudo nixos-rebuild switch --flake git+file:///etc/nixos#think14gryzen
```

After activation, verify the affected system and user services. A successful
check or build does not prove that the new generation is active.

Build the remote target:

```bash
nixos-rebuild build --flake git+file:///etc/nixos#plank
```

## Layout

```text
/etc/nixos/
├── flake.nix              # Flake inputs and host outputs
├── hosts/
│   ├── _template/         # Template for new hosts
│   ├── think14gryzen/     # Laptop configuration, assets, and host policy
│   └── plank/             # Remote bootstrap configuration
├── modules/
│   ├── nixos/             # Shared base, desktop, hardware, services, development
│   └── home/              # Shared Home Manager modules and adjacent assets
├── users/will/            # Account, Home Manager baseline, personal applications
├── pkgs/                  # Custom packages and their patches
├── theme/                 # Theme settings, templates, and generators
├── scripts/bench/         # Hardware and developer benchmarks
└── docs/                  # Guides and archived notes
```

Each host selects its shared features in `hosts/<host>/default.nix`. The shared
base is headless. Laptop LLM, power, and desktop helpers live under
`hosts/think14gryzen/system/` and `home/`; shared static assets live beside
their consuming Home Manager module.

`users/will/packages.nix` is a Home Manager module and owns personal application
selection in the user profile. Genuinely system-wide tools and desktop
integration remain in `environment.systemPackages` under
`hosts/<host>/system/packages.nix`. Custom package definitions and patches live
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
  `theme/scripts/` and `theme/templates/` own this flow; the former Nautilus
  **Scripts > Set as Wallpaper** entry is retired. SDDM keeps its separate image.

## Guides

- [`docs/README.md`](./docs/README.md): documentation index.
- [`docs/guides/HOST_ONBOARDING.md`](./docs/guides/HOST_ONBOARDING.md): add a host.
- [`docs/guides/LOCAL_LLM.md`](./docs/guides/LOCAL_LLM.md): local LLM workflow.
- [`docs/guides/PLANK_REMOTE_INSTALL.md`](./docs/guides/PLANK_REMOTE_INSTALL.md): remote installation.
- [`docs/guides/HARDWARE_BENCHMARK.md`](./docs/guides/HARDWARE_BENCHMARK.md): repeatable benchmarks.
