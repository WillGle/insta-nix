# Module inventory

`default.nix` is the entrypoint of a module. `home.nix` is the Home Manager
implementation used by a NixOS module that owns both layers; hosts do not import
feature Home Manager modules directly.

NixOS modules that own a Home Manager side wire it themselves:

```nix
home-manager.users.${config.primaryUser.username}.imports = [ ./home.nix ];
```

## Hosts and user

| Module | Layer | Entrypoint | Owns | Consumers |
|---|---|---|---|---|
| `hosts/minimal` | NixOS | `default.nix` | UEFI installer identity, console policy | `flake.nix` |
| `hosts/laptop` | NixOS | `default.nix` | Laptop identity, hardware composition, host policy | `flake.nix` |
| `hosts/laptop/packages.nix` | NixOS | imported by host | Host-bound diagnostics, benchmarks, network/media tools | Host |
| `base` | NixOS | `default.nix` | Shared headless baseline and `primaryUser.username` option | Both hosts |
| `users/will/default.nix` | NixOS | imported by host | Account and primary-user identity | Both hosts |
| `users/will/home.nix` | Home Manager | `home.nix` | User identity, personal packages, CLI aggregator | `flake.nix` `homeModule` |
| `users/will/packages.nix` | Home Manager | imported by user home | Personal application selection | `users/will/home.nix` |

## CLI

| Module | Layer | Entrypoint | Owns | Consumers |
|---|---|---|---|---|
| `modules/cli` | Home Manager | `default.nix` | Shell, terminal, XDG aggregation | `users/will/home.nix` |
| `modules/cli/shell` | Home Manager | `default.nix` | Fish, Starship, FZF, Zoxide, Direnv, Fastfetch, aliases | `modules/cli` |
| `modules/cli/terminal.nix` | Home Manager | file | Foot, Tmux, Yazi | `modules/cli` |
| `modules/cli/xdg.nix` | Home Manager | file | MIME defaults, XDG dirs, terminal dconf | `modules/cli` |

## Desktop

| Module | Layer | Entrypoint | Owns | Consumers |
|---|---|---|---|---|
| `modules/desktop/default.nix` | NixOS | `default.nix` | SDDM, audio, input method, portal, Qt, nix-ld, desktop platform; wires HM `home.nix` | Hosts with desktop |
| `modules/desktop/home.nix` | Home Manager | `home.nix` | Theme/session/hyprland/waybar/rofi/apps aggregation | `modules/desktop/default.nix` |
| `modules/desktop/packages.nix` | NixOS | imported by desktop | Desktop integration packages, fonts, cursors, Rofi override | `modules/desktop/default.nix` |
| `modules/desktop/bluetooth.nix` | NixOS + HM dconf | imported by desktop | Blueman service, D-Bus/systemd packages, dconf plugin list | `modules/desktop/default.nix` |
| `modules/desktop/session.nix` | Home Manager | imported by desktop home | Wallpaper/theme/Hyprpaper/Dunst/Udiskie/Blueman/Cliphist/Polkit user services | `modules/desktop/home.nix` |
| `modules/desktop/theme/default.nix` | NixOS | `default.nix` | Theme option schema and assertions | `modules/desktop/default.nix` |
| `modules/desktop/theme/defaults.nix` | Nix | imported by theme | Default color/font/cursor/wallpaper values | `modules/desktop/theme/default.nix` |
| `modules/desktop/theme/home.nix` | Home Manager | `home.nix` | Template deployment, generated links, theme-apply/wallpaper scripts | `modules/desktop/home.nix` |
| `modules/desktop/theme/lib/palette.sh` | Shell library | sourced | Runtime Matugen palette loader | Screen-time, atomic-note, rofi-calendar |
| `modules/desktop/hyprland/default.nix` | Home Manager | `default.nix` | Hyprland config/assets, helper scripts, session target | `modules/desktop/home.nix` |
| `modules/desktop/hyprland/input-method.nix` | Home Manager | imported by hyprland | Fcitx5 session-start boundary | Hyprland module |
| `modules/desktop/waybar/default.nix` | Home Manager | `default.nix` | Waybar config, bar helpers, user unit lifecycle | `modules/desktop/home.nix` |
| `modules/desktop/rofi/default.nix` | Home Manager | `default.nix` | Rofi platform, generic menus/themes, network helper | `modules/desktop/home.nix` |
| `modules/desktop/rofi/lib/menu.sh` | Shell library | sourced | Rofi dmenu protocol, markup escaping, row emission, theme resolution | Screen-time, rofi-network, Waybar helpers |
| `modules/desktop/apps/default.nix` | Home Manager | `default.nix` | Atomic Note and screen-time aggregation | `modules/desktop/home.nix` |
| `modules/desktop/apps/atomic-note` | Home Manager | `default.nix` | `atomic-note` script and assets | `modules/desktop/apps` |
| `modules/desktop/apps/screen-time` | Home Manager | `default.nix` | 5-second tracker, Summary/Activity dashboard, Waybar data, category map, 2 user units | `modules/desktop/apps`, `modules/desktop/waybar` |
| `modules/desktop/lib/network.sh` | Shell library | sourced | NetworkManager query helpers | Rofi network menu, Waybar network info |

## System

| Module | Layer | Entrypoint | Owns | Consumers |
|---|---|---|---|---|
| `modules/system/hardware/default.nix` | NixOS | `default.nix` | Firmware, Bluetooth, OpenLogi, usbmuxd | `hosts/laptop` |
| `modules/system/hardware/bluetooth.nix` | NixOS | imported by hardware | Bluetooth ghost-prune service | Hardware module |
| `modules/system/hardware/openlogi.nix` | NixOS | imported by hardware | OpenLogi option, daemon, udev rules | Hardware module |
| `modules/system/hardware/graphics-amd.nix` | NixOS | imported by host | AMD graphics, firmware, Mesa/VA-API/OpenCL packages | `hosts/laptop` |
| `modules/system/development/default.nix` | NixOS | `default.nix` | Wireshark, Nix audit tools, IaC/Kubernetes/Docker aggregation | `hosts/laptop` |
| `modules/system/development/docker.nix` | NixOS | imported by development | Docker daemon and storage driver | Development module |
| `modules/system/ssh/default.nix` | NixOS | `default.nix` | OpenSSH policy and `primaryUser` allow-list | Hosts |
| `modules/system/maintenance/default.nix` | NixOS + HM home | `default.nix` | Journal maintenance, fstrim, `home-cleanup` wiring | `hosts/laptop` |
| `modules/system/maintenance/home.nix` | Home Manager | `home.nix` | `home-cleanup` script/unit/timer and desktop-entry quarantine activation | Maintenance NixOS module |
| `modules/system/maintenance/assets/home-cleanup.sh` | Shell asset | built by `mk-script` | Cache/log/history pruning and broken desktop-entry quarantine | Maintenance HM module |
| `modules/system/power/default.nix` | NixOS | `default.nix` | Power profile, native power policy aggregation | `hosts/laptop` |
| `modules/system/power/native-power.nix` | NixOS | imported by power | Native profile scripts, sudo rules, services, assets | Power module |
| `modules/system/llm/default.nix` | NixOS | `default.nix` | Local LLM packages, wrappers, assets | `hosts/laptop` |
| `modules/system/gaming.nix` | NixOS | file | Steam, gamemode, gaming policy | `hosts/laptop` |

## Shared Nix helpers

| Helper | Owns | Consumers |
|---|---|---|
| `lib/mk-script.nix` | `writeShellApplication` wrapper for shebang assets with placeholder rendering | System and desktop modules |
| `lib/mk-home-script.nix` | Home Manager `mkScript` + `scriptFile` pair | Atomic Note, screen-time, Hyprland, Rofi, Waybar |
