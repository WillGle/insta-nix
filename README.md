# NixOS Flake Configuration - Laptop

This repository contains the complete NixOS configuration for my **AMD Ryzen** laptop, structured for maintainability and performance using Flakes.

## System Architecture

The configuration is split into specialized modules for clarity:

- **[flake.nix](flake.nix)**: Entry point. Defines inputs (NixOS 25.11 stable & Unstable) and host configuration.
- **[hardware-configuration.nix](hardware-configuration.nix)**: Hardware-specific generated config (UUIDs, boot modules).
- **`modules/`**:
  - **[boot.nix](modules/boot.nix)**: EFI Bootloader (systemd-boot), mount points, and kernel params.
  - **[services.nix](modules/services.nix)**: Core daemons (SSH, Docker, Flatpak) and Locale settings.
  - **[perf.nix](modules/perf.nix)**: Performance tuning (zram, AMD P-State Active), and Nix GC.
  - **[desktop.nix](modules/desktop.nix)**: Hyprland, SDDM, fcitx5, and Wayland session variables.
  - **[gpu.nix](modules/gpu.nix)**: AMDGPU kernel driver and hardware acceleration (VA-API/Vulkan).
  - **[audio.nix](modules/audio.nix)**: PipeWire, Bluetooth, and Blueman.
  - **[networking.nix](modules/networking.nix)**: NetworkManager with systemd-resolved and firewall rules.
  - **[users.nix](modules/users.nix)**: User account definitions and shell (fish/starship).
  - **[packages.nix](modules/packages.nix)**: System utilities (CLI) and Audit tools (`statix`, `deadnix`).
  - **[gaming.nix](modules/gaming.nix)**: Steam, GameMode, and gaming-related tools.
  - **[fonts.nix](modules/fonts.nix)**: Multi-font setup with Nerd Fonts and Emoji support (Noto).
- **[home.nix](home.nix)**: Home Manager user config. Manages:
  - **User Apps**: Browsers (Brave), Dev tools (VSCode), Office (WPS), Media (Obsidian).
  - **Shell**: Fish, Starship, Direnv.
  - **Desktop**: Hyprland, Waybar, Wofi, XDG defaults.
- **`dotfiles/`**: Source files for desktop environment configs (Hyprland, Waybar, Wofi, kanshi, scripts).

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

## Advanced Architecture Notes

### Hardware Optimizations (AMD Ryzen)

- **Kernel**: Switched to `linuxPackages_zen` for better desktop responsiveness.
- **P-State**: Running in `active` mode for optimal frequency scaling.
- **Ryzen SMU**: `ryzen-smu` kernel module enabled for advanced CPU metrics and control.
- **Early KMS**: Driver `amdgpu` is loaded in initrd to prevent boot flickering.
- **ROCm**: Enabled for GPU-accelerated computing (AI/ML and OpenCL) in [gpu.nix](modules/gpu.nix).
- **Power Scripts**: Custom `waybar-power-monitor` in `~/.local/bin/` for real-time wattage monitoring and profile switching.

### Premium Authentication UI

- **SDDM**: Using `sddm-astronaut-theme` for a modern login experience.
- **Lock Screen**: **Hyprlock** provides a high-performance, minimalist lock screen with wallpaper blur.
- **Idle Management**: **Hypridle** handles screen dimming and automatic locking for efficiency.
- **Polkit**: **Pantheon Polkit Agent** provides premium-feel elevation prompts.

### Input Method (Vietnamese)

- **Framework**: Fcitx5 with UniKey and Bamboo engines.
- **Compatibility**: Environment variables managed in Hyprland for GTK, Qt5/6, and Electron support.
- **Wayland Native**: Optimized by unsetting `GTK_IM_MODULE` to favor native Wayland protocols.

---

## Home Manager (Active)

Home Manager is fully integrated as a NixOS flake module. It manages:

- **Shell**: Fish, Starship prompt, Direnv
- **Desktop**: Hyprland, Waybar, Wofi, Kanshi configs
- **Scripts**: `~/.local/bin/` waybar helpers
- **XDG**: User directories, default applications

Managed files in `~/.config/` are read-only. Edit sources in `dotfiles/`, then rebuild.

---

## Notes

- **Power Management**: The system uses `amd_pstate=active`. Profile switching and monitoring are handled by the custom `waybar-power-monitor` script (toggle via Waybar icon or CLI).
- **Maintenance**: Nix Garbage Collection runs weekly automatically, keeping the last 14 days of generations.
