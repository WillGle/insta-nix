{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware.nix
    ../../base/default.nix
    ../../users/will/default.nix
  ];

  primaryUser.username = "will";

  networking.hostName = lib.mkDefault "nixos";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  hardware.enableRedistributableFirmware = true;

  # The installer deliberately creates no swap.
  swapDevices = lib.mkForce [ ];

  users.users.${config.primaryUser.username}.extraGroups = [
    "wheel"
    "networkmanager"
  ];

  # Keep the installed system small and usable on old hardware.
  documentation.enable = false;
  documentation.nixos.enable = false;
  boot.tmp.tmpfsSize = lib.mkForce "25%";
  nix.settings = {
    keep-outputs = lib.mkForce false;
    keep-derivations = lib.mkForce false;
  };

  environment.systemPackages = with pkgs; [
    curl
    git
  ];

  system.stateVersion = "25.11";
}
