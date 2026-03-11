{ lib, pkgs, ... }:
let
  repoRoot = builtins.toString ../..;
  localPlankModule = "${repoRoot}/.local/remote-install/modules/plank-host-local.nix";
  hasLocalPlankModule = builtins.pathExists localPlankModule;
in
{
  imports =
    [
      ../../profiles/shared/base.nix
      ../../profiles/shared/users-plank.nix
    ]
    ++ lib.optional hasLocalPlankModule localPlankModule;

  networking = {
    hostName = "generic-installer";
    networkmanager.enable = true;
    firewall.enable = true;
  };

  services = {
    # Keep generic installer profile lean.
    flatpak.enable = lib.mkForce false;
    tailscale.enable = lib.mkForce false;
    ollama.enable = lib.mkForce false;
    blueman.enable = lib.mkForce false;
  };

  hardware.bluetooth.enable = lib.mkForce false;

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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  warnings = lib.optionals (!hasLocalPlankModule) [
    "generic-installer: optional local override module not found at ${localPlankModule}"
  ];
}
