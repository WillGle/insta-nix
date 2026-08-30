{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/openlogi.nix
    ../../modules/nixos/llm.nix
    ../../modules/nixos/ryzen.nix
    ../../modules/nixos/desktop-integration.nix
    ../../users/will.nix
    ./system.nix
    ../../modules/nixos/roles/kubernetes.nix
    ../../modules/nixos/roles/iac.nix
  ];

  system.stateVersion = "25.11";
}
