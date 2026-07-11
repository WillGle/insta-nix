{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/openlogi.nix
    ../../users/will.nix
    ./system.nix
    ../../modules/nixos/roles/kubernetes.nix
    ../../modules/nixos/roles/iac.nix
  ];
}
