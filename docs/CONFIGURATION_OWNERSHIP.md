# Configuration ownership

This is the agent-facing contract for the NixOS and Home Manager
configuration in this repository. A visible file under `~/.config` is not
necessarily an independent source: a Home Manager link and its `/nix/store`
target are deployment artifacts.

## Core invariants

- ONE RUNTIME PATH → ONE OWNER
- ONE SEMANTIC SETTING → ONE AUTHORITATIVE CONFIGURATION LAYER

A shared directory is a namespace, not an owner. Different producers may own
different files in `~/.config`, `~/.local/bin`, `~/.config/systemd/user`,
Fish `functions/`, or Fish `completions/`. Check the individual path and the
setting it controls.

## Ownership classification

- **DECLARATIVE** — The canonical source is NixOS or Home Manager. The
  runtime target is deployment output and is not manually editable.
- **GENERATED** — A runtime generator creates the output from another
  canonical source. Manual edits will be overwritten.
- **MUTABLE** — Application or user runtime state intentionally changes over
  time. It is not automatically a candidate for Nix management.
- **EXTERNAL** — Configuration intentionally managed outside this repository.
  It may be migrated later as a deliberate task.
- **UNKNOWN** — Ownership has not been established. Inspect it before any
  mutation.

## Canonical configuration layers

- NixOS sources in `modules/nixos/` and `hosts/*/system.nix` own system
  packages, services, hardware, `/etc`, and system-wide environment.
- Home Manager sources in `modules/home/`, host Home Manager files, and their
  assets own user packages, shell configuration, XDG files, and user services.
- Hyprland consumes compositor configuration deployed by Home Manager. The
  canonical source is `modules/home/hyprland-helpers.nix` and the relevant
  host asset, not the deployed file under `~/.config/hypr/`.
- Theme option values are defined by `modules/nixos/theme.nix` and
  `theme/default.nix`. Theme deployment and runtime-generator wiring are in
  `modules/home/desktop.nix`, `modules/home/desktop/waybar.nix`,
  `modules/home/desktop/session-services.nix`, `theme/templates/`, and
  `theme/scripts/`.

Foot, Yazi, Tmux, and Starship intentionally use static Home Manager values
for now; they are not additional runtime-theme sources.

## Theme hierarchy

These paths have different owners. Do not describe all of `~/.config/theme/`
as generated state:

```
~/.config/theme/templates/
    DECLARATIVE — Home Manager-managed, read-only source-template deployment.
    Edit /etc/nixos/theme/templates/ instead.

~/.config/theme/static.env
    DECLARATIVE — Home Manager-managed output from the theme Nix configuration.

~/.config/theme/theme-apply
    DECLARATIVE — Home Manager-managed executable.
    Edit the theme Nix wiring or theme/scripts/ instead.

~/.config/theme/generated/*
    GENERATED — runtime outputs owned by theme-apply/Matugen.
    Edit the templates or generator pipeline, not these files.

~/.local/state/theme/*
    MUTABLE — persistent wallpaper, lock, and runtime theme state.
```

Home Manager also owns consumer links such as `~/.config/rofi/theme.rasi`,
`~/.config/nvim/colors/matugen.lua`, `~/.config/hypr/hyprpaper.conf`, and
`~/.config/dunst/dunstrc` when they point into `theme/generated/`. The link is
declarative; its resolved generated target remains generator-owned.

## Other managed deployment targets

Do not edit these runtime targets directly. Change their canonical Nix or
asset source instead:

- `~/.config/starship.toml`
- `~/.config/fish/config.fish`
- `~/.config/foot/foot.ini`
- `~/.config/tmux/tmux.conf`
- `~/.config/yazi/yazi.toml`
- `~/.config/yazi/theme.toml`
- `~/.config/waybar/*`
- managed XDG MIME files
- Home Manager-managed user units under `~/.config/systemd/user/`

If a target is a symlink into `/nix/store`, do not replace it or convert it
to a regular file. Never edit `/nix/store` content.

## Mutable state

The following are intentionally mutable unless an ownership redesign is the
explicit task:

- `~/.config/fcitx5/profile`
- `~/.config/fcitx5/conf/*`
- `~/.config/fish/fish_variables`
- `~/.local/state/theme/*`
- `~/.local/state/hypr/*`
- runtime databases and session state

`fish_variables` may contain user PATH entries. `modules/home/shell.nix`
reasserts the Cargo path idempotently; do not add another declarative PATH
source or treat this as permission to replace Fish universal state.

Fcitx's package and addons are NixOS-owned, while its profile and `conf/`
files are mutable. Home Manager owns the Fcitx session-start boundary.

## External configuration

The following application settings intentionally remain outside Home Manager:

- Zed: `~/.config/zed/settings.json`
- VS Code: `~/.config/Code/User/settings.json`
- Antigravity: `~/.config/Antigravity IDE/User/settings.json`
- Pi configuration/state: `~/.pi/agent/`

`.bashrc`, `.zshrc`, `.profile`, editor settings, and application state not
referenced by a module are likewise external unless deliberately migrated.
These files may contain local endpoints, tokens, or application state. Before
adding a declarative source, inspect and migrate the current live
configuration deliberately.
Pi credentials, session state, and other local state under `~/.pi/agent/`
remain external and must not be committed.

## Semantic ownership

File ownership alone is insufficient. Several mechanisms can configure the
same semantic setting or lifecycle, including environment variables, PATH
entries, aliases, systemd daemon startup, XDG autostart, and shell
initialization hooks.

One semantic setting or lifecycle must have one authoritative configuration
layer, even when other layers consume it. For example, the current Blueman
and Fcitx setup removes competing package launchers where Home Manager owns
the user-session startup boundary. Do not add another autostart entry, user
unit, shell hook, or override to work around an ownership conflict.

## Agent write policy

Safe to inspect: everything.

Safe to directly modify:

- canonical source files owned by the current task;
- explicitly mutable or external state when the task specifically requires
  it.

Do not directly modify:

- generated deployment targets;
- `/nix/store` content;
- Home Manager-managed symlinks;
- runtime-generated outputs when their generator is the real source.

When a conflict is found, fix the owning source or stop for clarification.
Do not solve it by adding another override or another source of the same
setting.

## Unknown ownership procedure

Before modifying an unfamiliar runtime path:

1. Inspect whether it is a symlink.
2. Resolve the symlink target.
3. Search `/etc/nixos` for the path and application.
4. Check this document and the relevant module.
5. Classify the path as DECLARATIVE, GENERATED, MUTABLE, EXTERNAL, or
   UNKNOWN.

If ownership remains unclear, do not overwrite it. Report the path and the
missing evidence.

## Deliberately retained unknowns

These items remain unresolved or historical by design. Their presence is not
permission to delete, clean, or overwrite them:

- Home Manager `.backup` files with unique historical settings remain retained
  for recovery; the legacy-looking Home Manager generation links remain
  unresolved pending rollback verification.
- `/etc/nixos/scripts/bench/common.sh` still reads the optional historical
  `/run/ryzenadj-profile/active` marker for benchmark metadata; no active
  producer remains, and daily power ownership is `native-power-profile` with
  `/etc/native-power-profiles.tsv`.

## Module boundaries

- `modules/home/home-baseline.nix`: Home Manager identity and baseline.
- `modules/home/shell.nix`: Fish, Starship, FZF, Zoxide, Direnv, Fastfetch,
  aliases, and user shell environment.
- `modules/home/terminal.nix`: Foot, Tmux, and Yazi.
- `modules/home/xdg-defaults.nix`: MIME defaults, XDG user directories, and
  terminal dconf settings.
- `modules/home/desktop.nix`: theme deployment, generator wiring, and links
  to generated desktop surfaces.
- `modules/home/desktop/waybar.nix`: Waybar configuration, enablement, and
  Hyprland-session lifecycle.
- `modules/home/desktop/session-services.nix`: theme application, Hyprpaper,
  Dunst, Udiskie, Blueman, Cliphist, and the Polkit agent.
- `modules/home/input-method.nix`: Fcitx5 user-session startup boundary.
- `modules/home/hyprland-helpers.nix`: compositor configuration and helper
  services other than the input-method boundary.
- `hosts/think14gryzen/home.nix`: host-specific Home Manager imports plus
  Blueman desktop-entry and dconf settings.

The package-provided Waybar user unit is a fallback under the per-user
profile. The Home Manager unit under `~/.config/systemd/user/waybar.service`
intentionally shadows it so the Hyprland lifecycle has one active source.
