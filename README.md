# Insta-Nix (NixOS Flake Configuration)

A modular, multi-host NixOS & Home Manager Flake configuration featuring a personal laptop profile (`think14gryzen`) and a remote-install bootstrap target (`plank`).

---

## Flake Outputs

* **`think14gryzen`**: Primary personal laptop profile (Ryzen 780M, Hyprland, Home Manager, local LLMs, Waybar, Rofi suite).
* **`plank`**: Lightweight remote-install & bootstrap target for server or headless deployments.

List exported outputs locally:

```bash
nix flake show --no-write-lock-file git+file:///etc/nixos
```

---

## Repository Structure

```text
/etc/nixos/
├── flake.nix                  # Flake inputs & nixosConfigurations entrypoint
├── hosts/                     # Host-specific configurations & assets
│   ├── think14gryzen/         # Main host entrypoint and host-local policy
│   │   ├── default.nix        # Host composition and state version
│   │   ├── system.nix         # Host-wide policy and system-module composition
│   │   ├── hardware.nix       # Generated hardware configuration
│   │   ├── network.nix        # Host network policy
│   │   ├── storage.nix        # Host filesystems and swap
│   │   ├── home.nix           # Host-specific Home Manager additions
│   │   └── system/            # Coherent host system responsibilities
│   │       ├── user.nix       # Account, shell, and host user policy
│   │       ├── graphics.nix   # AMD graphics and firmware stack
│   │       ├── power.nix      # Power, kernel tuning, and zram
│   │       ├── gaming.nix     # Steam and Gamemode
│   │       └── packages.nix   # System packages, fonts, and Blueman integration
│   └── plank/                 # Remote bootstrap target
├── modules/                   # Reusable feature modules
│   ├── nixos/                 # System-level NixOS modules
│   │   ├── base.nix           # Core NixOS defaults
│   │   ├── llm.nix            # llama.cpp Vulkan stack & local LLM tool suite
│   │   ├── ryzen.nix          # Ryzen laptop power management & battery reserve limit
│   │   ├── desktop-integration.nix # SDDM, Pipewire low-latency, Fcitx5, XDG portals
│   │   └── openlogi.nix       # Organization/work tooling
│   └── home/                  # User-level Home Manager modules
│       ├── home-baseline.nix  # Home Manager identity and baseline
│       ├── shell.nix          # Fish, Starship, FZF, Zoxide, Direnv, Fastfetch
│       ├── terminal.nix       # Foot, Tmux, and Yazi
│       ├── xdg-defaults.nix   # MIME, XDG user dirs, and terminal dconf
│       ├── input-method.nix   # Fcitx5 user-session boundary
│       ├── base.nix           # Compatibility import for shared Home Manager modules
│       ├── desktop.nix        # Shared desktop environment apps
│       ├── desktop/waybar.nix # Waybar enablement and session lifecycle
│       ├── desktop/session-services.nix # User session daemons and agents
│       ├── screen-time.nix    # Rofi app usage tracker & study timer suite
│       ├── waybar-helpers.nix # Waybar status monitors (memory, network, power)
│       └── hyprland-helpers.nix # Hyprland setup, touchpad toggle, & helper scripts
├── users/                     # Shared user base definitions
└── theme/                     # Dynamic desktop color theme engine & templates
```

See [`docs/CONFIGURATION_OWNERSHIP.md`](./docs/CONFIGURATION_OWNERSHIP.md) for
the source-of-truth rules and the list of generated files that must not be
edited directly.

---

## User-facing Scripts

Scripts are packaged using `writeShellApplication` with pinned runtime dependencies
and deployed by their NixOS or Home Manager module:

* **Local LLM Suite (`llm.nix`):**
  * `llmfit`: Browse catalog models scored against this laptop's memory budget.
  * `llm-pull`: Fetch GGUF models directly from HuggingFace into local model dir.
  * `llm-list`: List installed GGUFs; `llm-list --detail <file.gguf>` shows metadata and hardware fit.
  * `llm-fit`: Model-agnostic GPU VRAM / GTT overflow fit calculator.
  * `llm-run`: Auto-sized, overflow-safe `llama-server` launcher (Vulkan backend).

See [`docs/guides/LOCAL_LLM.md`](./docs/guides/LOCAL_LLM.md) for the complete
discover, download, inspect, fit, and serve workflow.

* **Power & Battery (`ryzen.nix`):**
  * `native-power-profile`: Four Lenovo/amd-pstate profiles (`power-saver`, `balanced`, `sustained-build`, `performance`).
  * `toggle-battery-reserve`: Toggles Lenovo battery conservation mode.
* **Desktop & Utilities (`modules/home/`):**
  * `rofi-screen-time`: Interactive app usage dashboard & study session tracker.
  * `waybar-*`: Real-time system monitoring scripts for memory, network, and power consumption.
  * `toggle_touchpad.sh` & `rotate_select.sh`: Hyprland input and monitor workspace scripts.

---

## Usage & Deployment

### Build & Apply Configuration

```bash
# Validate flake structure
nix flake check --no-build --no-write-lock-file git+file:///etc/nixos

# Test-build system derivation
nixos-rebuild dry-build --flake /etc/nixos#think14gryzen

# Apply configuration locally
sudo nixos-rebuild switch --flake /etc/nixos#think14gryzen
```

### Remote Bootstrap Target (`plank`)

To build or deploy the remote bootstrap target:

```bash
nixos-rebuild build --flake git+file:///etc/nixos#plank
```

Follow the detailed guide in [`docs/guides/PLANK_REMOTE_INSTALL.md`](./docs/guides/PLANK_REMOTE_INSTALL.md) for target disk partition scripts and remote bootstrap workflows.
