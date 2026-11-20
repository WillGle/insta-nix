{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../base/default.nix
    ../../modules/system/ssh/strict.nix
    ../../users/will/default.nix
    ./system.nix
  ];

  system.stateVersion = "25.11";
}
