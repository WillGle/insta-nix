# NixOS Configuration with Flakes – Progress & Next Steps

This file tracks what has already been completed in your NixOS flake migration, and what remains to be done.

---

## Completed Steps

- [x] **Backed up existing dotfiles**
  ```bash
  cp -a ~/.config ~/dotfiles-backup-$(date +%F)
  ```

- [x] **Initialized Git repo in `/etc/nixos`**
  ```bash
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

- [x] **Created `flake.nix` using existing `configuration.nix` + `hardware-configuration.nix`**

- [x] **Successfully rebuilt system using flake**
  ```bash
  sudo nixos-rebuild switch --flake .#Laptop
  ```

- [x] **Created module stubs for future modularization**
  ```bash
  mkdir -p /etc/nixos/modules
  touch desktop.nix gpu.nix audio.nix laptop-power.nix networking.nix users.nix gaming.nix packages.nix
  ```

- [x] **Fixed repo permissions (`chown -R will:users /etc/nixos`)**

- [x] **Pushed config to GitHub**
  ```bash
  git remote add origin git@github.com:WillGle/Insta_Nix.git
  git branch -M main
  git push -u origin main
  ```

---

## To-Do

### Modularize `configuration.nix` into `modules/*.nix` (one-by-one)
- [ ] `modules/desktop.nix` → Hyprland, SDDM, xdg.portal, fonts, input method
- [ ] `modules/networking.nix` → NetworkManager, firewall, DNS, resolved
- [ ] `modules/laptop-power.nix` → TLP, powerManagement, `amd_pstate`
- [ ] `modules/gpu.nix` → amdgpu, vulkan, vaapi, xserver
- [ ] `modules/audio.nix` → PipeWire, pulseaudio = false, Bluetooth, rtkit
- [ ] `modules/users.nix` → User `will`, sudo rules, shell config
- [ ] `modules/packages.nix` → `environment.systemPackages` list
- [ ] `modules/gaming.nix` → Steam, GameMode, Mangohud

### Enable Home-Manager for user configuration (`~/.config`)
- [ ] Add `home-manager` as input in `flake.nix`
- [ ] Create `home/will/home.nix`
- [ ] Use `xdg.configFile` to symlink dotfiles (e.g. waybar, rofi, hypr, kanshi)
- [ ] Gradually convert some to `programs.*` Home-Manager native modules

### Set up `devShell` for ML development
- [ ] Add `devShells.ml` to `flake.nix` with Python + ML packages (numpy, pandas, jupyter, sklearn)
- [ ] Test with `nix develop .#ml`

### Add secret management (optional)
- [ ] Add `agenix` or equivalent if you plan to handle secrets declaratively

### Optional advanced: remote deployment
- [ ] Add `deploy-rs` for multi-machine deployment

---

## Notes

- Use `sudo nixos-rebuild switch --flake .#Laptop` for every change
- Use `git commit` after each change, then `git push`
- To recover system on a new machine:
  ```bash
  git clone git@github.com:WillGle/Insta_Nix.git /etc/nixos
  sudo nixos-rebuild switch --flake /etc/nixos#Laptop
  ```
