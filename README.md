# NixOS Flake Configuration - Laptop

This repository contains the complete NixOS configuration for my **AMD Ryzen** laptop, structured for maintainability and performance using Flakes.

## System Architecture

The configuration is split into specialized modules for clarity:

- **[flake.nix](flake.nix)**: Entry point. Defines inputs (NixOS 25.11 stable & Unstable) and host configuration.
- **[hardware-configuration.nix](hardware-configuration.nix)**: Hardware-specific generated config (UUIDs, boot modules).
- **`modules/`**:
  - **[core.nix](modules/core.nix)**: System-wide defaults, GC protection, and TTY palette.
  - **[desktop.nix](modules/desktop.nix)**: Hyprland, SDDM, Polkit UI, and centralized Fcitx5 config.
  - **[connectivity.nix](modules/connectivity.nix)**: Hardened Networking (DNS over TLS, DNSSEC), Audio (PipeWire), and Bluetooth.
  - **[hardware.nix](modules/hardware.nix)**: Kernel pinning (LTS 6.12), P-State, Ryzenadj, and disk mounting.
  - **[services.nix](modules/services.nix)**: Hardened SSH, Tailscale, and other system daemons.
  - **[users.nix](modules/users.nix)**: User account definitions and specialized sudo rules.
  - **[packages.nix](modules/packages.nix)**: Core system utilities, CLI tools, and theme assets.
  - **[apps.nix](modules/apps.nix)**: GUI applications, media tools, and browsers.
  - **[theme.nix](modules/theme.nix)**: Centralized "Source of Truth" for system-wide hex colors.
  - **[gaming.nix](modules/gaming.nix)**: Steam and gaming optimization tools.
  - **[fonts.nix](modules/fonts.nix)**: Nerd Fonts and emoji support.
- **[home.nix](home.nix)**: Home Manager user config (Foot, waybar, and per-user dotfile mapping).
- **`dotfiles/`**: Source files for desktop environment configs (Hyprland, Waybar, Wofi, kanshi).

---

## Maintenance & Code Quality

### Audit & Rigidity

The configuration follows a strict "Rigidity - Stability - Standardize - Unification" philosophy.

- **Formatting**: All `.nix` files are formatted with `nixfmt`.
- **Linting**: Enforced via `statix` (logic checks) and `deadnix` (unused code removal).
- **Strict Scripts**: All shell scripts use `set -euo pipefail` for safety.

Run the audit suite:

```bash
nix shell nixpkgs#statix nixpkgs#deadnix nixpkgs#nixfmt-rfc-style nixpkgs#git --command bash -c "statix check . && deadnix . && nixfmt --check \$(git ls-files '*.nix')"
```

### Verification Steps

Run these commands to validate the system state:

1. **Lint & Format**: Ensures code rigidity.

   ```bash
   nix shell nixpkgs#statix nixpkgs#deadnix nixpkgs#nixfmt-rfc-style nixpkgs#git --command bash -c "statix check . && deadnix . && nixfmt --check \$(git ls-files '*.nix')"
   ```

   *> Note: Uses `git ls-files` to ignore build artifacts (like `result/`).*

2. **System Build**: Ensures the configuration is valid and builds.

   ```bash
   nixos-rebuild build --flake .#Laptop
   ```

3. **Script Runtime**: Verifies shell script stability.

   ```bash
   dotfiles/local-bin/waybar-memory-info
   dotfiles/local-bin/verify-optimization
   ```

### Daily Use

### Apply Changes

To apply configuration changes immediately:

```bash
sudo nixos-rebuild switch --flake .#Laptop
```

To apply changes only for the next boot (useful for kernel/driver updates):

```bash
sudo nixos-rebuild boot --flake .#Laptop
```

### Update System

1. Update sources (flake.lock): `sudo nix flake update`
2. Apply updates: `sudo nixos-rebuild switch --flake .#Laptop`

### Troubleshooting & Rollback

Switch to the previous generation if something breaks:

```bash
sudo nixos-rebuild switch --rollback
```

List system generations:

```bash
nix-env --list-generations --profile /nix/var/nix/profiles/system
```

### Cleanup & Disk Space

Delete old generations to free up space:

```bash
# Delete older than 7 days
sudo nix-collect-garbage --delete-older-than 7d
# Full hard cleanup
sudo nix-collect-garbage -d
```

### Package Search

Search for available packages:

```bash
nix-env -qaP <name>
# OR use nix-search if installed
nix-search <name>
```

---

## Remote & Re-Installation Guide

### Option 1: Manual Re-installation (Local)

1. Boot from a NixOS Live ISO.
2. Partition and mount your drives.
3. Clone this repository into `/mnt/etc/nixos`:

   ```bash
   git clone <repo-url> /mnt/etc/nixos
   ```

4. Install:

   ```bash
   nixos-install --flake /mnt/etc/nixos#Laptop
   ```

### Option 2: Remote Installation (via nixos-anywhere)

To install this configuration on a remote AMD laptop via SSH:

1. Ensure the remote machine is booted into a NixOS installer with SSH enabled.
2. From your development machine:

   ```bash
   npx nixos-anywhere --flake .#Laptop root@remote-ip
   ```

---

### System Hardening & Security

- **DNS over TLS**: All DNS queries are encrypted via `systemd-resolved` (Cloudflare) with DNSSEC validation.
- **SSH Protocol**: Hardened to port 2222 with password authentication disabled and root login restricted.
- **Kernel Pinning**: Locked to the **LTS 6.12** series to ensure the AMD platform and `ryzen-smu` modules remain stable between updates.
- **GC Protection**: Configuration uses `keep-outputs` to prevent the garbage collector from breaking system rollbacks.

### Hardware Optimizations (AMD Ryzen)

- **P-State**: Running in `active` mode for optimal frequency scaling.
- **Ryzen SMU**: `ryzen-smu` kernel module enabled for advanced CPU metrics and control.
- **Early KMS**: Driver `amdgpu` is loaded in initrd to prevent boot flickering.
- **ROCm**: Enabled for GPU-accelerated computing (AI/ML and OpenCL) in [connectivity.nix](modules/connectivity.nix).

### Custom Tooling: `waybar-power-monitor`

A specialized script (`~/.local/bin/waybar-power-monitor`) monitors the Ryzen APU limits:

- **`apu` Mode**: Combined CPU+GPU Temp, Package Power, and Frequency/Usage stats.
- **`sys` Mode**: Calculated System/Screen power (Total - APU).
- **`pwr` Mode**: Real-time Battery Charge/Discharge flow.

### Premium Authentication & Desktop UI

- **SDDM**: Using `sddm-astronaut-theme` (Qt5 stable) for a modern, reliable login experience.
- **Lock Screen**: **Hyprlock** provides a high-performance, minimalist lock screen with wallpaper blur.
- **Polkit UI**: **LXQt PolicyKit** provides dependable elevation prompts integrated via systemd.
- **XWayland**: Scaling and cursors are synchronized using `xrdb` to ensure legacy applications look premium on high-DPI panels.

### Input Method (Vietnamese)

- **Framework**: Fcitx5 with **UniKey** engine centered in `desktop.nix`.
- **Centralization**: All fmod and environment variables are managed at the system level for total consistency across GTK, Qt, and Electron apps.

---

## Home Manager (Active)

Home Manager is fully integrated as a NixOS flake module, serving as the **Single Source of Truth (SSOT)** for user configurations. It manages:

- **Shell**: Fish, Starship prompt, Direnv.
- **Display Management**: **Kanshi** manages dynamic monitor profiles with manual `exec-once` invocation for stability.
- **Native Waybar**: Fully styled via Home Manager with dynamic color injection from [theme.nix](modules/theme.nix).
- **Dotfiles**: Authoritative source in `dotfiles/` directory, symlinked to `~/.config/`.
- **XDG**: User directories and default application associations.

Managed files in `~/.config/` are read-only to ensure system rigidity. Edit sources in `dotfiles/`, then rebuild.

---

## Notes

- **Power Management**: The system uses `amd_pstate=active`. Profile switching and monitoring are handled by the custom `waybar-power-monitor` script (toggle via Waybar icon or CLI).
- **Maintenance**: Nix Garbage Collection runs weekly automatically, keeping the last 14 days of generations.
