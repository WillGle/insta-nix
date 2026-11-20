{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../base/default.nix
    ../../modules/system/ssh/plank.nix
    ../../users/will/default.nix
    ./system.nix
  ];

  system.stateVersion = "25.11";
}
