{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../base/default.nix
    ../../modules/nixos/services/ssh/strict.nix
    ../../users/will/default.nix
    ./system
  ];

  system.stateVersion = "25.11";
}
