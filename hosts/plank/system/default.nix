{ lib, pkgs, ... }:
{
  users.users.will = {
    shell = pkgs.bashInteractive;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # SSH key is the primary auth gate for Plank; avoid password lockout after first boot.
  security.sudo.wheelNeedsPassword = false;

  hardware = {
    # Keep standard redistributable firmware, without every firmware blob.
    enableAllFirmware = false;
    enableRedistributableFirmware = true;
  };

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
}
