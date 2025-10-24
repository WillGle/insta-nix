{ config, lib, pkgs, ... }:

{
  # ───────── Filesystems ─────────
  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/GENERIC_VAULT_UUID";
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };

  # ───────── Environment vars ─────────
  # Keep these null to avoid IM warnings/overrides
  environment.variables = {
    GTK_IM_MODULE = lib.mkForce null;
    QT_IM_MODULE  = lib.mkForce null;
  };

  # If any other module tries to set these, mkForce keeps them unset.
  environment.sessionVariables = {
    # UI
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE  = "24";
    QT_FONT_DPI   = "144";
    QT_SCALE_FACTOR = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";

    # Input
    INPUT_METHOD = lib.mkForce null;
    XMODIFIERS   = lib.mkForce null;
    GTK_IM_MODULE = lib.mkForce null;
    QT_IM_MODULE  = lib.mkForce null;
  };

  # ───────── Bootloader ─────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "amd_pstate=active" ];

  # ───────── CPU / FW ─────────
  hardware.cpu.amd.updateMicrocode = true;

  # ───────── Locale / Time ─────────
  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "vi_VN"; LC_IDENTIFICATION = "vi_VN"; LC_MEASUREMENT = "vi_VN";
    LC_MONETARY = "vi_VN"; LC_NAME = "vi_VN"; LC_NUMERIC = "vi_VN";
    LC_PAPER = "vi_VN"; LC_TELEPHONE = "vi_VN"; LC_TIME = "vi_VN";
  };

  # ───────── Virtualization ─────────
  virtualisation.docker.enable = true;

  # ───────── Core Services ─────────
  services.dbus.enable = true;
  services.openssh.enable = true;
  services.flatpak.enable = true;
  services.upower.enable = true;
  services.udev.enable = true;
  services.acpid.enable = true;(fcitx removed)
  security.polkit.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # sudo rule for tlp
  security.sudo.extraRules = [{
    users = [ "will" ];
    commands = [{ command = "/run/current-system/sw/bin/tlp"; options = [ "NOPASSWD" ]; }];
  }];

  # ───────── Nix (flakes) ─────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ───────── Nix settings ─────────
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.05";
}
