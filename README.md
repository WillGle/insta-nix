# NixOS Configuration with Flakes — Progress & Next Steps

This file tracks where your flake migration currently stands and how to work safely going forward.

---

## Completed Steps

- [x] **Backed up existing dotfiles**
  ```bash
  cp -a ~/.config ~/dotfiles-backup-$(date +%F)
  ```

- [x] **Initialized Git repo in `/etc/nixos`**
  ```bash
  cd /etc/nixos
  sudo git init
  sudo git add .
  sudo git commit -m "Baseline before enabling flakes"
  ```

- [x] **Enabled flakes and garbage collection**
  - Added to `configuration.nix`:
    ```nix
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    ```

- [x] **Created `flake.nix`** that loads `hardware-configuration.nix`, **thin** `configuration.nix`, and split modules.

- [x] **Split configuration into modules and wired them in `flake.nix`**
  - `modules/desktop.nix` — Hyprland, SDDM, XKB, XDG portals, input method (fcitx5)
  - `modules/gpu.nix` — `amdgpu` video driver (xserver)
  - `modules/audio.nix` — PipeWire (PulseAudio off), **`security.rtkit.enable = true;`**, Bluetooth + Blueman
  - `modules/networking.nix` — NetworkManager, firewall, resolved
  - `modules/laptop-power.nix` — TLP, powerManagement, `amd_pstate=active`
  - `modules/users.nix` — user `will`, fish + starship, sudo rule for `tlp`
  - `modules/packages.nix` — common packages
  - `modules/gaming.nix` — Steam, GameMode

- [x] **Removed duplicate definitions from `configuration.nix`**
  - `security.rtkit.enable` now **only** in `modules/audio.nix`
  - `i18n.inputMethod`, `xdg.portal`, `services.xserver.enable/xkb` moved to `modules/desktop.nix`
  - `services.xserver.videoDrivers` moved to `modules/gpu.nix`
  - `hardware.bluetooth.enable` + `services.blueman.enable` moved to `modules/audio.nix`

- [x] **Verified effective values with `nixos-option`**
  ```bash
  nixos-option services.pipewire.enable
  nixos-option xdg.portal.enable
  nixos-option users.users.will.shell
  ```

- [x] **Successfully rebuilt system via flake**
  ```bash
  sudo nixos-rebuild switch --flake /etc/nixos#Laptop
  ```

- [x] **Pushed config to GitHub**
  ```bash
  git remote add origin git@github.com:WillGle/Insta_Nix.git
  git branch -M main
  git push -u origin main
  ```

---

## Current Layout

```
/etc/nixos
├─ flake.nix
├─ configuration.nix        # thin base (boot, FS, nix settings, core services, stateVersion)
├─ hardware-configuration.nix
└─ modules/
   ├─ audio.nix
   ├─ desktop.nix
   ├─ gpu.nix
   ├─ laptop-power.nix
   ├─ networking.nix
   ├─ packages.nix
   ├─ users.nix
   └─ gaming.nix
```

> **Rule of thumb:** keep `configuration.nix` *thin*; edit per-topic in `modules/*.nix`.

---

## Daily Workflow

1) Edit the relevant module (audio/desktop/gpu/…).  
2) Rebuild (from flake root):
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#Laptop
   ```
3) Commit & push:
   ```bash
   sudo git add -A
   sudo git commit -m "update: <what you changed>"
   sudo git push
   ```

> If you see `warning: Git tree '/etc/nixos' is dirty`, just commit the changes.  
> If you run commands from `/etc/nixos/modules`, Nix may say *“path … does not contain a 'flake.nix', searching up”* — that’s informational; prefer running from `/etc/nixos` or pass the absolute flake path as above.

---

## Duplicate-Check & Verification

**Scan for common duplicates:**
```bash
nix run nixpkgs#ripgrep -- -n "users\.users\.will|programs\.(fish|starship|zsh)|services\.(pipewire|pulseaudio|rtkit|xdg|blueman|sddm|xserver)|security\.rtkit|hardware\.bluetooth|xdg\.portal|i18n\.inputMethod" /etc/nixos
```

**See which file defines an option (after rebuild):**
```bash
nixos-option services.pipewire.enable
nixos-option security.rtkit.enable
nixos-option xdg.portal.enable
nixos-option services.xserver.videoDrivers
nixos-option i18n.inputMethod
```
Aim for **“Defined by:”** pointing to the **module** that owns that topic.

---

## To-Do

### Finish/Confirm modularization (sanity pass)
- [ ] Ensure `configuration.nix` no longer contains: `i18n.inputMethod`, `xdg.portal`, `services.xserver.*`, `hardware.bluetooth`, `services.blueman`, `pipewire/pulseaudio/rtkit`.  
- [ ] Keep these **only** in their respective module files above.

### Enable Home-Manager for user configuration (`~/.config`)
- [ ] Add input to `flake.nix`:
  ```nix
  inputs.home-manager.url = "github:nix-community/home-manager/release-25.05";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
  ```
- [ ] Add `hm.nix` and import HM:
  ```nix
  # flake.nix → modules = [ … ({ ... }: { _module.args.inputs = { inherit home-manager; }; }) ./hm.nix ];
  ```
- [ ] Create `home/will/home.nix` and begin migrating dotfiles via `xdg.configFile` or native `programs.*`.

### Set up `devShell` for ML development
- [ ] Add to `flake.nix`:
  ```nix
  devShells.${system}.ml = pkgs.mkShell {
    packages = with pkgs; [
      python312
      (python312.withPackages (ps: with ps; [
        pip numpy pandas jupyterlab scikit-learn matplotlib
      ]))
      git
    ];
  };
  ```
- [ ] Test:
  ```bash
  nix develop .#ml
  ```

### Secret management (optional)
- [ ] Add `agenix` input, generate age key, declare secrets for services/tokens.

### Remote deployment (optional)
- [ ] Add `deploy-rs` if you plan multi-machine deployments.

---

## Troubleshooting Cheatsheet

- **“defined multiple times”**  
  → The option is *unique* (e.g., `users.users.will.shell`). Keep it in **one** file.  
  Use `rg` to find all occurrences, delete duplicates, rebuild.

- **`services.rtkit` does not exist`**  
  → Use **`security.rtkit.enable = true;`** on your channel.

- **`path '…/modules' does not contain a 'flake.nix', searching up`**  
  → Run from flake root (`/etc/nixos`) or pass `/etc/nixos#Host`.

- **`Git tree is dirty`**  
  → Commit changes:
  ```bash
  sudo git add -A && sudo git commit -m "checkpoint"
  ```

---

## Notes

- Rebuild with:
  ```bash
  sudo nixos-rebuild switch --flake /etc/nixos#Laptop
  ```
- Commit after each change, then push.
- Restore on a fresh machine:
  ```bash
  sudo rm -rf /etc/nixos
  sudo git clone git@github.com:WillGle/Insta_Nix.git /etc/nixos
  sudo nixos-rebuild switch --flake /etc/nixos#Laptop
  ```
