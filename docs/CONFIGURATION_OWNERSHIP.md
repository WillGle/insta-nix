# Configuration ownership

This repository uses NixOS for system scope and Home Manager for the `will`
user scope. A file under `~/.config` is not an independent source merely
because it is visible there: if Home Manager links it into `/nix/store`, the
link and store content are deployment artifacts.

## Ownership rules

- NixOS owns system packages, system services, hardware, `/etc`, and
  system-wide environment.
- Home Manager owns user packages, shell configuration, XDG files, user
  services, and user-facing application settings.
- Hyprland owns compositor/session-specific environment variables only.
- Runtime theme generation owns the generated desktop surfaces listed by the
  theme pipeline. Foot, Yazi, Tmux, and Starship intentionally use static
  Home Manager values for now; this is a hybrid theme model.
- Fcitx5's package and addons are NixOS-owned. Its profile and `conf` files
  are explicitly user-owned mutable state; Home Manager owns only session
  startup.
- On `think14gryzen`, package-provided Blueman and Fcitx XDG autostart entries
  are filtered out so the Home Manager user units are the only session launchers.
- `.bashrc`, `.zshrc`, `.profile`, editor settings, and application state not
  referenced by a module remain external user-owned files until deliberately
  migrated.
- `~/.config/fish/fish_variables` is mutable Fish universal state. It currently
  carries user PATH entries; `shell.nix` reasserts the Cargo path idempotently,
  so this remains an explicit migration exception rather than a second managed
  `config.fish` source.

## Deliberately external applications

The following are installed by NixOS where applicable but are configured
outside this repository. Do not add a second Home Manager settings source
without first migrating the live settings and checking for secrets:

- Zed: `~/.config/zed/settings.json`
- VS Code: `~/.config/Code/User/settings.json`
- Antigravity: `~/.config/Antigravity IDE/User/settings.json`
- Pi: `~/.pi/agent/models.json`

These files may contain local endpoints, tokens, or application state. The
local-LLM guide documents the paths, but the files themselves are not committed
configuration.

## Deliberately retained candidates

The following were not deleted because runtime ownership is not proven from the
repository alone:

- `~/.local/share/mimeapps.list` is an empty unmanaged file; the populated
  XDG files are the Home Manager links above.
- `~/.config/theme/runtime/` has no current repository consumer; the active
  runtime pipeline uses `~/.config/theme/generated/`.
- Timestamped Yazi files, Home Manager `.backup` files, and the disabled
  `~/.config/systemd/user/cpda-goal-fleet.timer` remain historical/external
  state until separately verified.
- `hosts/think14gryzen/assets/system-bin/ryzenadj-profile` refers to the old
  `/etc/ryzenadj-profiles.tsv` contract; the active module installs and uses
  `native-power-profile` with `/etc/native-power-profiles.tsv`. It remains in
  the repository pending an explicit stale-asset decision.

## Module boundaries

- `modules/home/home-baseline.nix`: Home Manager identity and baseline.
- `modules/home/shell.nix`: Fish, Starship, FZF, Zoxide, Direnv, Fastfetch,
  aliases, and user shell environment.
- `modules/home/terminal.nix`: Foot, Tmux, and Yazi.
- `modules/home/xdg-defaults.nix`: MIME defaults, XDG user directories, and
  terminal dconf settings.
- `modules/home/desktop.nix`: theme generation and generated desktop files.
- `modules/home/desktop/waybar.nix`: Waybar enablement and Hyprland-session
  configuration and lifecycle.
- `modules/home/desktop/session-services.nix`: theme application, Hyprpaper,
  Dunst, Udiskie, Blueman, Cliphist, and the Polkit agent.
- `modules/home/input-method.nix`: Fcitx5 user-session startup boundary.
- `modules/home/hyprland-helpers.nix`: compositor configuration and helper
  services other than the input-method boundary.

## Generated targets

Do not edit these directly; change their declarative source instead:

- `~/.config/starship.toml`
- `~/.config/fish/config.fish`
- `~/.config/foot/foot.ini`
- `~/.config/tmux/tmux.conf`
- `~/.config/yazi/yazi.toml` and `theme.toml`
- `~/.config/waybar/config.jsonc` and `style.css`
- `~/.config/mimeapps.list` and `~/.local/share/applications/mimeapps.list`
- Home Manager-managed user units under `~/.config/systemd/user/`
- generated theme files under `~/.config/theme/`

The generated theme directory is intentionally mutable runtime state for the
selected desktop theme pipeline. It is not a place for manual edits.

Waybar's package-provided user unit is a fallback under the per-user profile;
the Home Manager unit under `~/.config/systemd/user/waybar.service` intentionally
shadows it so the Hyprland lifecycle is defined in one source.
