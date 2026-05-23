{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../modules/nixos/base.nix
    ../../users/will.nix
    ./system.nix
  ];
}
