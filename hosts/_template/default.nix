{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../modules/nixos/base.nix
    ../../users/will/default.nix
    ./system.nix
  ];
}
