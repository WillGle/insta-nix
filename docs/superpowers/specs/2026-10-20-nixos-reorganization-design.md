# NixOS repository reorganization

Date: 2026-10-20

## Intended result

Reorganize the existing two-host configuration so each host selects its own
features, shared modules have no dependency on a named host, and package
definitions have clear owners. Preserve working desktop, hardware, development,
and remote-bootstrap behavior. Use the existing NixOS module system and Home
Manager integration.

This is a source-organization change. Package upgrades and changes to the live
generation are separate actions.

## Existing decisions to preserve

- `6b280bb`: host-based configuration with reusable modules.
- `54d5a75`: separate NixOS and Home Manager ownership, including session startup.
- `9d3aa8d`: separate laptop packages, graphics, power, user, and gaming policy.
- `54b5579`: retain the Antigravity watcher patch and its version guard.
- Keep stable graphics drivers for the system and the scoped unstable Vulkan
  configuration for llama.cpp. Preserve the selected kernel and compatibility
  patches, input-method addons, Bluetooth startup, and power-profile policy.

## Target organization

```text
flake.nix                     Inputs and composition of named hosts
flake.lock                    Existing pinned dependencies
hosts/<host>/default.nix       Host feature selection
hosts/<host>/hardware.nix      Host hardware
hosts/<host>/storage.nix       Host storage
hosts/<host>/network.nix       Host networking
hosts/<host>/system.nix        Host system policy and imports
hosts/<host>/home.nix          Host Home Manager policy and imports
hosts/<host>/system/           Substantial host-specific system components
hosts/<host>/home/             Substantial host-specific Home Manager components
hosts/<host>/assets/           Host-specific source assets
modules/nixos/base/            Shared Nix, locale, networking, and system baseline
modules/nixos/desktop/         Shared desktop integration
modules/nixos/hardware/        Reusable hardware integrations
modules/nixos/services/        Reusable service and SSH integrations
modules/nixos/development/     IaC and Kubernetes client tools
modules/home/shell/            Fish, Starship, and shell integrations
modules/home/terminal/         Foot, Tmux, and Yazi
modules/home/waybar/           Shared Waybar configuration
modules/home/theme/            Home Manager theme deployment and session wiring
modules/home/xdg.nix           Shared XDG configuration
users/will/default.nix         NixOS account and personal package selection
users/will/home.nix            Home Manager identity and common user imports
users/will/packages.nix        Existing personal application package selection
pkgs/<package>/default.nix     Custom package definitions
pkgs/<package>/*.patch         Patches next to their owning package
theme/                        Existing theme values, templates, and generators
scripts/                      Maintenance and benchmark tools
docs/guides/                  Current operational guidance
docs/archive/                 Preserved historical evidence
```

Create component directories only where actual files need them. Shared static
assets move beside their consuming Home Manager module; the root `assets/`
directory disappears after its consumers have been updated. Keep `theme/` as
the source used by both NixOS theme options and Home Manager deployment.

## Composition and ownership

### Hosts and shared modules

`flake.nix` continues to expose `think14gryzen` and `plank`, using the current
stable and unstable inputs. It integrates Home Manager only for hosts that
enable it. The host Home Manager entrypoint imports the user's baseline and
the desktop features needed by that host; enabling Home Manager alone does
not implicitly select a desktop.

Move code that depends on laptop assets or laptop-specific runtime limits
under `hosts/think14gryzen/`. This includes the current LLM and native-power
helpers and the Home Manager helper modules for Hyprland, Waybar, and screen
time. Update relative source paths without introducing an asset-discovery
framework or extra configuration layers.

The shared system baseline stops enabling desktop features. Move the current
desktop service, Bluetooth, Logitech, and nix-ld selections to the laptop's
desktop/hardware imports. Select Tailscale explicitly on the laptop. Retain
shared settings that currently apply to both hosts, such as locale, DNS,
firewall defaults, Nix settings, and temporary-directory policy.

`plank` imports only its required baseline, account, SSH, network, boot, and
storage definitions. Remove desktop disabling overrides only after evaluation
proves the corresponding features still evaluate to disabled. Split its boot
hardware, storage, and networking definitions into the named host files without
changing devices, labels, authentication, or firewall policy.

Keep the SDDM wallpaper seed and any other personal runtime source path in
the laptop host configuration, retaining its current copy-once behavior.

### Packages

Retain every selected package, its input channel, custom patch, and installed
scope. Prefer the existing `programs.*` and `services.*` integration where
already enabled. Do not switch existing applications between the system and
user profiles during this structural change.

`users/will/packages.nix` is initially a NixOS module containing the existing
personal application selection. Home Manager packages continue to come from
the corresponding Home Manager modules. This preserves command availability
while giving personal application selection one location.

Move the custom Antigravity, Blueman, Fcitx, and Lightworks package definitions
to their own `pkgs/` directories, retaining derivation names, build logic,
dependency channels, and startup filtering. Service registration stays in the
module that owns the service.

Keep development tools under their role modules. Remove the duplicate host
declaration of Ansible and place Terraform beside the existing IaC tool
selection. Keep both Terraform and OpenTofu because they are distinct tools.
Do not remove repetitions automatically introduced by upstream NixOS modules.

### Runtime configuration and documentation

Preserve generated configuration paths, unit names, environment values, and
Home Manager ownership. Do not migrate external editor settings, toolchains,
application state, or credentials. Do not modify Pi, pi-harness, or pi-acp.

Update the README, host onboarding, and active references affected by moves.
Preserve archived documents as historical records. Correct the local agent
entrypoint's `.agent/` references to `.agents/`; local policy remains outside
version control.

## Verification and acceptance

Before moving files, capture both hosts' evaluated package paths and important
service settings, and the laptop's managed Home Manager paths and user units.
Preserve the pre-existing `flake.lock` bytes throughout the work.

After reorganization:

1. Both named host outputs evaluate with the unchanged lockfile.
2. Each host's unique system package set is unchanged, apart from no changes
   being needed for removing repeated declarations of the same package.
3. The laptop's Home Manager package set, managed target paths, session unit
   names, and configuration content remain equivalent. Source store paths may
   change when source files move; inspect those differences before accepting.
4. Shared modules contain no direct reference to `hosts/think14gryzen/` or to
   the personal SDDM source image.
5. Plank remains headless with its current SSH and installation behavior.
6. Existing formatter, Statix, Deadnix, and `git diff --check` checks pass for
   the changed Nix sources. No new test suite is introduced.
7. Run flake evaluation and full builds for both hosts. Report any build or
   dependency blocker separately from source-validation results.
8. Inspect the complete final diff for accidental behavior changes and stale
   active references. Leave switching and runtime verification as separate
   operations; successful builds do not establish live activation.

## Scope limits

No dependency updates, broad cleanup of backups or local state, deletion of
historical evidence, new configuration framework, or changes to the active
NixOS generation. Preserve unrelated dirty state and do not stage the existing
lockfile change.
