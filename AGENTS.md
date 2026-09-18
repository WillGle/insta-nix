# Agent configuration contract

Before modifying any NixOS or Home Manager configuration, read
docs/CONFIGURATION_OWNERSHIP.md. Preserve these invariants:

- ONE RUNTIME PATH → ONE OWNER
- ONE SEMANTIC SETTING → ONE AUTHORITATIVE CONFIGURATION LAYER

## Write policy

Safe to inspect: everything.

Safe to directly modify:

- canonical Nix, asset, template, or generator-source files owned by the task;
- explicitly mutable or external runtime files only when the task specifically
  requires it.

Do not directly modify deployment targets, /nix/store content, Home Manager
symlinks, or runtime-generated outputs. Never solve a conflict by adding
another override or another source for the same setting.

## Managed Nix/Home Manager targets

If a runtime file is generated or linked by NixOS/Home Manager:

- do not edit it directly;
- do not replace its symlink;
- do not convert a /nix/store symlink into a regular file;
- modify the canonical .nix source instead.

Examples include:

- ~/.config/starship.toml
- ~/.config/fish/config.fish
- ~/.config/foot/foot.ini
- ~/.config/tmux/tmux.conf
- ~/.config/yazi/yazi.toml
- ~/.config/yazi/theme.toml
- ~/.config/waybar/*
- managed XDG MIME files;
- Home Manager-managed systemd user units.

## Runtime-generated artifacts

Runtime generators may own mutable outputs. Do not manually edit their
generated outputs unless the task is to change the generator itself. For
example, ~/.config/theme/generated/* is owned by theme-apply/Matugen; change
the theme pipeline or its templates instead.

## Mutable state

Do not automatically migrate mutable state into Nix. The following are
intentionally allowed to remain mutable unless ownership redesign is the
explicit task:

- ~/.config/fcitx5/profile
- ~/.config/fcitx5/conf/*
- ~/.config/fish/fish_variables
- ~/.local/state/theme/*
- ~/.local/state/hypr/*
- runtime databases and session state.

## External application configuration

Zed, VS Code, and Antigravity are intentionally configured outside Home
Manager. Pi configuration/state under ~/.pi/agent/ is also external.
Credentials, session state, and other local Pi state must not be committed.
~/.bashrc, ~/.zshrc, and ~/.profile are also external where documented.
Do not introduce a second declarative source without first inspecting and
migrating the current live configuration.

## Shared namespaces

~/.config, ~/.local/bin, ~/.config/systemd/user, Fish functions/, and Fish
completions/ may contain files owned by different producers. A shared
directory is not automatically a conflict: check the individual path and
semantic setting.

## Unknown ownership

Before modifying an unfamiliar runtime file:

1. Check whether it is a symlink.
2. Resolve the symlink target.
3. Search /etc/nixos for the path or application.
4. Read docs/CONFIGURATION_OWNERSHIP.md.
5. Classify it as declarative, generated, mutable, external, or unknown.

If ownership remains unclear, do not overwrite it. Report the path and the
missing evidence instead.
