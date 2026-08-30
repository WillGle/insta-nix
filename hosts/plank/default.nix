{ lib, pkgs, ... }:
{
  imports = [
    ../../modules/nixos/base.nix
    ../../users/will.nix
  ];

  users.users.will = {
    shell = pkgs.bashInteractive;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # SSH key is the primary auth gate for Plank; avoid password lockout after first boot.
  security.sudo.wheelNeedsPassword = false;

  networking = {
    hostName = "plank";
    networkmanager.enable = true;
    firewall.enable = true;
  };

  services = {
    # The shared base includes desktop conveniences; keep this remote bootstrap
    # target limited to its network and SSH requirements.
    flatpak.enable = lib.mkForce false;
    tailscale.enable = lib.mkForce false;
    ollama.enable = lib.mkForce false;
    blueman.enable = lib.mkForce false;
    upower.enable = lib.mkForce false;
    acpid.enable = lib.mkForce false;
    udisks2.enable = lib.mkForce false;
    gvfs.enable = lib.mkForce false;
  };

  hardware = {
    # Keep standard redistributable firmware, without every firmware blob.
    enableAllFirmware = lib.mkForce false;
    enableRedistributableFirmware = lib.mkForce true;
    logitech.wireless.enable = lib.mkForce false;
    bluetooth.enable = lib.mkForce false;
  };

  programs.nix-ld.enable = lib.mkForce false;

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "sd_mod"
      "usbhid"
      "rtsx_pci_sdmmc"
    ];
  };

  # Plank uses fixed disk labels so install flow is deterministic without disko.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_ROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXOS_BOOT";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-label/NIXOS_SWAP"; }
  ];

  environment.systemPackages = with pkgs; [
    git
    curl
    vim
  ];

  system.nixos.tags = [
    "plank"
    "generic-installer"
  ];

  system.stateVersion = "25.11";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
