{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware.nix
    ../../base/default.nix
    ../../modules/system/maintenance
    ../../modules/system/hardware
    ../../modules/system/llm
    ../../modules/system/power
    ../../modules/system/gaming.nix
    ../../modules/desktop/default.nix
    ../../modules/system/ssh
    ../../users/will/default.nix
    ./system.nix
    ../../modules/system/development
  ];

  networking = {
    hostName = "laptop";

    firewall = {
      # ProtonVPN replies use the physical NIC; strict reverse-path filtering
      # drops them. Force loose mode to preserve asymmetric routing.
      checkReversePath = lib.mkForce "loose";
      trustedInterfaces = [
        "proton0"
      ];
    };
  };

  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/GENERIC_VAULT_UUID";
    fsType = "ext4";
    options = [
      "defaults"
      "noatime"
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # The machine owner accepts near-root group access for daily administration.
  users.users.will = {
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "seat"
      "audio"
      "dialout"
      "bluetooth"
      "docker"
      "render"
      "wireshark"
    ];
  };

  programs.fish.enable = true;

  # Home Manager owns ll; remove the competing NixOS default.
  environment.shellAliases.ll = lib.mkForce null;

  system.stateVersion = "25.11";
}
