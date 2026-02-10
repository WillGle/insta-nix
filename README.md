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
  - **[packages.nix](modules/packages.nix)**: Global system package lists.
  - **[gaming.nix](modules/gaming.nix)**: Steam, GameMode, and gaming-related tools.
  - **[fonts.nix](modules/fonts.nix)**: Multi-font setup with Nerd Fonts and Emoji support (Noto).
- **[home.nix](home.nix)**: Home Manager user config (Fish, Starship, Direnv, XDG, mimeapps).
- **`dotfiles/`**: Source files for desktop environment configs (Hyprland, Waybar, Wofi, kanshi, scripts).

---

## Installation & Build

### Local Application

To apply changes locally after editing:

```bash
sudo nixos-rebuild switch --flake .#Laptop
```

### Dry-Run Verification

Verify evaluation and build without switching:

```bash
nixos-rebuild dry-activate --flake .#Laptop
```

### Update Flake Inputs

```bash
nix flake update
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
- **Early KMS**: Driver `amdgpu` is nạp sớm (loaded in initrd) to prevent boot flickering.
- **ROCm**: Enabled for GPU-accelerated computing (AI/ML and OpenCL) in [gpu.nix](modules/gpu.nix).
- **P-State EPP**: Managed via `power-profiles-daemon` for consistent and conflict-free frequency scaling.

### Compatibility Overrides (Workarounds)

Due to occasional build failures in the latest NixOS branch:

- **DeaDBeeF**: Pinned to **NixOS 24.11** branch. This bypasses a known compilation error in the `swift` dependency on 25.11.

---

## Future: Home Manager Transition

To eventually manage `~/.config/` via Nix, follow these catchup steps:

### 1. The Strategy

- **Phase 1**: Add Home Manager as a Flake input.
- **Phase 2**: Start with one app (e.g., `git` or `fish`) to test symlinking.
- **Phase 3**: Move `Hyprland` and complex configs.

### 2. Quick Catchup for Action

- **ReadOnly**: Managed files in `~/.config/` will become read-only. Edit the Nix source, then rebuild.
- **Backups**: Use `home-manager.backupFileExtension = "backup";` to avoid conflicts with existing config files.
- **Commands**:

  ```bash
  nix flake update home-manager
  ```

---

## Notes

- **Power Management**: The system uses `amd_pstate=active`. Use `powerprofilesctl` to switch modes.
- **Maintenance**: Nix Garbage Collection runs weekly automatically, keeping the last 14 days of generations.
