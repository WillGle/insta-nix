# Module inventory

`default.nix` is a module entrypoint. A NixOS module that owns a Home Manager
side wires it itself:

```nix
home-manager.users.${config.primaryUser.username}.imports = [ ./home.nix ];
```

Hosts do not import feature Home Manager modules.

## Hosts and user

| Module | Layer | Owns | Used by |
|---|---|---|---|
| `hosts/minimal` | NixOS | UEFI installer identity, console policy | `flake.nix` |
| `hosts/laptop` | NixOS | Laptop identity, hardware composition, host policy | `flake.nix` |
| `hosts/laptop/packages.nix` | NixOS | Host-only diagnostics, benchmarks, network/media tools | Host |
| `base` | NixOS | Shared headless baseline and `primaryUser.username` option | Both hosts |
| `users/will/default.nix` | NixOS | Account and primary-user identity | Both hosts |
| `users/will/home.nix` | Home Manager | User identity, personal packages, CLI aggregator | `flake.nix` `homeModule` |
| `users/will/packages.nix` | Home Manager | Personal application selection | `users/will/home.nix` |

## CLI

| Module | Layer | Owns | Used by |
|---|---|---|---|
| `modules/cli` | Home Manager | Shell, terminal, XDG aggregation | `users/will/home.nix` |
| `modules/cli/shell` | Home Manager | Fish, Starship, FZF, Zoxide, Direnv, Fastfetch, aliases | `modules/cli` |
| `modules/cli/terminal.nix` | Home Manager | Foot, Tmux, Yazi | `modules/cli` |
| `modules/cli/xdg.nix` | Home Manager | XDG dirs, terminal dconf | `modules/cli` |

## Desktop

| Module | Layer | Owns | Used by |
|---|---|---|---|
| `modules/desktop/default.nix` | NixOS | SDDM, audio, input method, portal, Qt, nix-ld, MIME defaults, desktop platform; wires HM `home.nix` | Hosts with desktop |
| `modules/desktop/mime.nix` | NixOS | System MIME defaults in `/etc/xdg/mimeapps.list` | Desktop default |
| `modules/desktop/home.nix` | Home Manager | Theme, session, Hyprland, Waybar, Rofi, apps aggregation | Desktop default |
| `modules/desktop/packages.nix` | NixOS | Desktop integration packages, fonts, cursors, Rofi override | Desktop default |
| `modules/desktop/bluetooth.nix` | NixOS + HM dconf | Blueman service, D-Bus/systemd packages, dconf plugin list | Desktop default |
| `modules/desktop/session.nix` | Home Manager | Wallpaper, theme, Hyprpaper, Dunst, Udiskie, Blueman, Cliphist, Polkit user services | Desktop home |
| `modules/desktop/theme/default.nix` | NixOS | Theme option schema and assertions | Desktop default |
| `modules/desktop/theme/defaults.nix` | Nix | Default color, font, cursor, and wallpaper values | Theme default |
| `modules/desktop/theme/home.nix` | Home Manager | Template deployment, generated links, theme-apply/wallpaper scripts | Desktop home |
| `modules/desktop/hyprland/default.nix` | Home Manager | Hyprland config/assets, helper scripts, session target | Desktop home |
| `modules/desktop/hyprland/input-method.nix` | Home Manager | Fcitx5 session-start boundary | Hyprland module |
| `modules/desktop/waybar/default.nix` | Home Manager | Waybar config, bar helpers, user unit lifecycle | Desktop home |
| `modules/desktop/rofi/default.nix` | Home Manager | Rofi base theme/config and general modes | Desktop home |
| `modules/desktop/apps/default.nix` | Home Manager | Atomic Note aggregation | Desktop home |
| `modules/desktop/apps/atomic-note` | Home Manager | `atomic-note` script and assets | Apps default |
| `modules/desktop/lib/network.sh` | Shell library | NetworkManager query helpers | Waybar network info |

## System

| Module | Layer | Owns | Used by |
|---|---|---|---|
| `modules/system/hardware/default.nix` | NixOS | Firmware, Bluetooth, OpenLogi, usbmuxd | `hosts/laptop` |
| `modules/system/hardware/bluetooth.nix` | NixOS | Bluetooth ghost-prune service | Hardware module |
| `modules/system/hardware/openlogi.nix` | NixOS | OpenLogi option, daemon, udev rules | Hardware module |
| `modules/system/hardware/graphics-amd.nix` | NixOS | AMD graphics, firmware, Mesa/VA-API/OpenCL packages | `hosts/laptop` |
| `modules/system/development/default.nix` | NixOS | Wireshark, Nix audit tools, IaC/Kubernetes/Docker aggregation | `hosts/laptop` |
| `modules/system/development/docker.nix` | NixOS | Docker daemon and storage driver | Development module |
| `modules/system/ssh/default.nix` | NixOS | OpenSSH policy and `primaryUser` allow-list | Hosts |
| `modules/system/maintenance/default.nix` | NixOS + HM home | Journal maintenance, fstrim, `home-cleanup` wiring | `hosts/laptop` |
| `modules/system/maintenance/home.nix` | Home Manager | `home-cleanup` script/unit/timer and desktop-entry quarantine | Maintenance NixOS module |
| `modules/system/maintenance/assets/home-cleanup.sh` | Shell asset | Cache/log/history pruning and broken desktop-entry quarantine | Maintenance HM module |
| `modules/system/power/default.nix` | NixOS | Power profile and native power policy aggregation | `hosts/laptop` |
| `modules/system/power/native-power.nix` | NixOS | Native profile scripts, sudo rules, services, assets | Power module |
| `modules/system/llm/default.nix` | NixOS | Local LLM packages, wrappers, assets | `hosts/laptop` |
| `modules/system/gaming.nix` | NixOS | Steam, gamemode, gaming policy | `hosts/laptop` |

## Shared helpers

| Helper | Owns | Used by |
|---|---|---|
| `lib/mk-script.nix` | `writeShellApplication` wrapper for shebang assets with placeholder rendering | System and desktop modules |
| `lib/mk-home-script.nix` | Home Manager `mkScript` + `scriptFile` pair | Atomic Note, Hyprland, Rofi, Waybar |
