{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../modules/nixos/base/default.nix
    ../../modules/nixos/services/ssh/strict.nix
    ../../users/will/default.nix
    ./system.nix
  ];
}
