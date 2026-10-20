# NixOS Repository Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for sequential implementation, or superpowers:subagent-driven-development if the user selects delegation. Steps use checkbox syntax for tracking.

**Goal:** Give the two existing hosts, shared modules, personal configuration,
and custom packages clear source ownership while preserving their behavior.

**Architecture:** Keep the existing flake and NixOS/Home Manager integration.
Move host-dependent code under its host, group reusable modules by function,
and preserve the selected package outputs and runtime configuration.

**Tech Stack:** NixOS 25.11, Home Manager release-25.11, pinned nixpkgs-unstable.

**Spec:** [Approved design](../specs/2026-10-20-nixos-reorganization-design.md).

## Global Constraints

- Preserve both `think14gryzen` and `plank` outputs and existing package scope.
- Preserve `flake.lock` SHA-256 `c232c3976970a88e7caed0ff1ad93bec27cdaabfc1de97fa9416a6dea401a2bc`.
- Preserve package channels, patches, comments, session ownership, and mutable state.
- No switch, external application migration, Pi changes, or dependency upgrades.
- Use existing checks and disposable comparisons; do not add a test suite.
- Stage only explicit task paths; exclude the dirty lockfile and local policy.
- Keep notes and baseline exports under `/tmp/nixos-reorg-20261020/`.

## Review Focus

- New or moved sources must be included in validation without copying local-only files.
- Relative source moves must preserve rendered configuration and helper dependencies.
- Removing Plank overrides must not silently enable a service or change boot/storage.
- Custom package extraction must retain patched binaries and startup filtering.
- Personal package regrouping must preserve installation scope and stable/unstable selection.

## Task 1: Capture the existing configuration

**Files:** Read current sources; create disposable baseline records outside the repo.

**Interfaces:** Produces `before/<host>.json`, containing unique system package
paths, enabled services, system/user unit contents, boot/storage settings,
and laptop Home Manager package paths, managed target names and contents.

- [ ] Export tracked source into a disposable baseline directory; copy the
  existing dirty lockfile over the exported lock. Exclude local ignored policy.
- [ ] Evaluate both baseline hosts with `--no-write-lock-file` and save the
  records above. Save the current generation path and lockfile checksum.
- [ ] Run baseline formatting, Statix, Deadnix, and flake evaluation; record
  existing findings rather than treating them as regressions.

Expected: baseline records for both hosts, existing lint findings recorded,
and no repository-source edits.

## Task 2: Reorganize Home Manager and user entrypoints

**Files:** Move these sources and update all active imports and relative paths:

| Existing source | Destination |
|---|---|
| `users/will.nix` | `users/will/default.nix` |
| `modules/home/home-baseline.nix` | `users/will/home.nix` |
| `modules/home/shell.nix` | `modules/home/shell/default.nix` |
| `modules/home/terminal.nix` | `modules/home/terminal/default.nix` |
| `modules/home/xdg-defaults.nix` | `modules/home/xdg.nix` |
| `modules/home/desktop.nix` | `modules/home/theme/default.nix` |
| `modules/home/desktop/session-services.nix` | `modules/home/theme/session-services.nix` |
| `modules/home/desktop/waybar.nix` | `modules/home/waybar/default.nix` |
| `modules/home/input-method.nix` | `modules/home/hyprland/input-method.nix` |
| `modules/home/hyprland-helpers.nix` | `hosts/think14gryzen/home/hyprland.nix` |
| `modules/home/waybar-helpers.nix` | `hosts/think14gryzen/home/waybar.nix` |
| `modules/home/screen-time.nix` | `hosts/think14gryzen/home/screen-time.nix` |
| `assets/common/fastfetch/` | `modules/home/shell/assets/fastfetch/` |
| `assets/common/waybar/` | `modules/home/waybar/assets/` |
| `assets/common/rofi/` | `modules/home/rofi/assets/` |

**Interfaces:** `users/will/home.nix` owns identity and common shell/terminal/XDG
imports. Host `home.nix` owns desktop and helper imports. Flake Home Manager
wiring imports only the selected host Home Manager entrypoint.

- [ ] Perform the moves and preserve asset bytes and comments.
- [ ] Move Rofi-specific declarations from theme deployment into
  `modules/home/rofi/default.nix`; the theme module retains generated links
  and shared theme substitutions. Keep their runtime target names unchanged.
- [ ] Update the flake, host Home Manager entrypoint, and account imports;
  remove obsolete `modules/home/base.nix` after replacing every consumer.
- [ ] Evaluate both hosts and compare Home Manager target names, contents,
  package paths, and user units against Task 1. Explain any source-path-only
  difference; fix any semantic difference before proceeding.
- [ ] Commit the verified Home Manager reorganization using explicit paths.

## Task 3: Reorganize system modules and host selection

**Files:** Move `modules/nixos/base.nix` to `modules/nixos/base/default.nix`;
`desktop-integration.nix` to `desktop/default.nix`; `bluetooth.nix` and
`openlogi.nix` to `hardware/`; `ssh/` to `services/ssh/`; `roles/` to
`development/`; `theme.nix` to `desktop/theme.nix`; `llm.nix` and `ryzen.nix`
to `hosts/think14gryzen/system/llm.nix` and `native-power.nix` respectively.
Modify both host entrypoints, laptop system imports, the flake, and template.

**Interfaces:** Shared baseline is headless. Laptop imports select current
desktop/hardware features and Tailscale. Laptop native-power and LLM modules
reference their sibling host assets. SSH policy is selected by each host.

- [ ] Move files and update relative imports and source paths. Put the SDDM
  image activation script in `hosts/think14gryzen/system.nix` unchanged.
- [ ] Move current desktop service selections and nix-ld configuration from
  shared base into the desktop module, and hardware selections into
  `modules/nixos/hardware/desktop.nix`. Preserve all current values.
- [ ] Retain theme option availability for both hosts by importing the theme
  option definitions from the baseline; do not enable desktop services there.
- [ ] Split Plank's boot hardware, storage, and network into its named host
  files. Remove redundant disabling overrides only when baseline comparison
  confirms the same evaluated values. Preserve firmware, SSH, sudo, and users.
- [ ] Update the template imports and make SSH selection host-owned;
  simplify the flake helper accordingly without changing named outputs.
- [ ] Compare both hosts' service/unit, kernel, firmware, boot, storage,
  networking, environment, account, and power settings against Task 1.
- [ ] Verify no shared module refers directly to laptop assets or its image.
- [ ] Commit the verified system reorganization using explicit paths.

## Task 4: Give custom packages and application lists explicit owners

**Files:** Move `pkgs/antigravity-ide.nix` and its patch into
`pkgs/antigravity-ide/`. Create `pkgs/blueman/default.nix`,
`pkgs/fcitx5/default.nix`, `pkgs/lightworks/default.nix`, and
`users/will/packages.nix`. Modify laptop packages, account imports, desktop
input-method integration, and `modules/nixos/development/iac.nix`.

**Interfaces:** Custom package files return the current patched/wrapped
derivation via `callPackage`. `users/will/packages.nix` remains a NixOS
module using `environment.systemPackages`, preserving global availability.

- [ ] Extract the existing custom package definitions without changing
  derivation names, inputs, flags, patch checks, desktop entries, or filtering.
- [ ] Move browser, office/productivity, editor, and media application
  selections into `users/will/packages.nix`. Keep device/system/session tools,
  codecs, fonts, and integration packages with their existing system owner.
- [ ] Put Terraform in IaC and remove the repeated host Ansible declaration;
  preserve both Terraform and OpenTofu and all other selected tools.
- [ ] Compare unique system and Home Manager package paths for each host;
  inspect any derivation difference before accepting it. Verify custom
  package build definitions and session autostart filtering remain intact.
- [ ] Commit the verified package reorganization using explicit paths.

## Task 5: Update guidance and verify the complete source tree

**Files:** Update README and active guides affected by moves; correct ignored
local `AGENTS.md` references without committing it. Preserve archived evidence.

**Interfaces:** Final source exports use only tracked/non-ignored intended
files, including moved files; exclude `.agents/`, `.local/`, local policy,
credentials, and internal documents. Final records use Task 1's schema.

- [ ] Update active path examples and explain feature/package ownership.
  Replace onboarding `path:/etc/nixos` commands with Git-source commands and
  instruct users to add intended new host source files before validation.
- [ ] Format changed Nix files and resolve the baseline lint findings in
  files touched by the reorganization. Run `nixfmt --check`, `statix check`,
  `deadnix --fail`, and `git diff --check`.
- [ ] Run final flake checks and compare both exported configurations against
  Task 1. Inspect the complete diff for changed commands, service semantics,
  lost packages, and stale active references. Confirm the lock checksum.
- [ ] Build both `nixosConfigurations.<host>.config.system.build.toplevel`
  outputs with `--no-link --no-write-lock-file`. State any external failure
  accurately; do not switch as part of this task.
- [ ] Obtain a final read-only review of the complete change if the selected
  execution method includes a reviewer; resolve confirmed in-scope issues.
- [ ] Commit verified final documentation/source corrections with explicit
  paths. Report commit hashes, validation, and activation status separately.
