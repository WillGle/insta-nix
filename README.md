# Insta-Nix

Personal NixOS configuration for a AMD laptop and a minimal UEFI
install target.

## Hosts

- `laptop` — Hyprland desktop, Home Manager, local LLM tools, Waybar,
  Rofi.
- `minimal` — console-only NixOS for fresh installs and older hardware.

```bash
nix flake show --no-write-lock-file git+file:///etc/nixos
```

## Install

The installer wipes the target disk. UEFI x86_64 only; no swap.

```bash
curl -fsSLO https://raw.githubusercontent.com/WillGle/insta-nix/main/install.sh
sudo bash install.sh --disk /dev/nvme0n1
sudo reboot
```

The default host is `minimal`: console NixOS, NetworkManager, user `will`, no
desktop, no Home Manager. See
[`docs/guides/INSTALL.md`](./docs/guides/INSTALL.md) for options and
troubleshooting.

## Check, build, switch

```bash
make check
make build
```

Raw equivalent:

```bash
./scripts/validate.sh
nix build --no-link --no-write-lock-file \
  git+file:///etc/nixos#nixosConfigurations.laptop.config.system.build.toplevel
```

`make` targets: `check`, `build`, `switch`, `diff`, `update`, `clean`.
`scripts/validate.sh` runs `git diff --check` and `nix flake check`
(formatting, statix, deadnix, shellcheck).

Enable the pre-commit hook:

```bash
git config core.hooksPath .githooks
```

Apply only after check and build pass:

```bash
sudo nixos-rebuild switch --flake git+file:///etc/nixos#laptop
```

After switching, verify the affected services. A successful build does not
prove the new generation is active.

## Layout

```text
/etc/nixos/
├── flake.nix
├── Makefile
├── install.sh
├── install/disko.nix
├── base/                  # shared headless baseline
├── hosts/                 # minimal, laptop
├── modules/
│   ├── cli/               # Home Manager: shell, terminal, XDG
│   ├── desktop/           # platform, theme, Hyprland, Waybar, Rofi
│   └── system/            # hardware, development, SSH, power, LLM
├── users/will/            # account, Home Manager identity, packages
├── pkgs/                  # custom packages and patches
├── lib/                   # shared Nix helpers
├── scripts/               # validation and benchmarks
└── docs/                  # guides and archive
```

- `hosts/<host>/default.nix` owns identity, composition, and host-only policy.
- NixOS modules wire their own Home Manager side under
  `home-manager.users.${config.primaryUser.username}`. Hosts do not import
  feature Home Manager modules.
- `primaryUser.username` is the single username source.
- Assets live next to the module that consumes them.
- `modules/desktop/packages.nix` owns desktop integration packages,
  `hosts/laptop/packages.nix` owns host-only tools, and
  `users/will/packages.nix` owns personal user packages.

See [`modules/README.md`](./modules/README.md) for the full module table.

Git flake commands include tracked working-tree changes. `git add` new source
files before validation. Keep local state and credentials outside the Git
source.

## Ownership

- **NixOS** — system packages, services, hardware, `/etc`, system environment.
- **Home Manager** — user packages, shell/XDG config, user services.
- **Generated** — `~/.config/theme/generated/` is runtime output; edit the
  templates or `modules/desktop/theme/` instead.
- **External** — Pi, Zed, VS Code, and other unreferenced app settings are
  user-owned; they are not managed here.

## Daily tools

- **LLM** — `llmfit`, `llm-pull`, `llm-list`, `llm-fit`.
- **Power** — `native-power-profile`, `toggle-battery-reserve`.
- **Desktop** — `waybar-*`, Hyprland helper scripts.
- **Screen Time** — `Super+I` or `rofi-screen-time`; provided by the `rofi-hub`
  NixOS module. [Upstream docs](https://github.com/WillGle/screen-time-rofi#readme)
- **Wallpaper** — Nautilus **Set as Background**, `wallpaper pick`, or
  `wallpaper set <image>`. `wallpaper set` copies the image to
  `~/.local/state/theme/wallpapers/`, Matugen updates the palette, and
  Hyprpaper applies it. SDDM keeps a separate image.

## Docs

- [`docs/README.md`](./docs/README.md) — documentation index.
