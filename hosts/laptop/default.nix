{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../modules/nixos/base/default.nix
    ../../modules/nixos/hardware/desktop.nix
    ../../modules/nixos/hardware/openlogi.nix
    ./system/llm.nix
    ./system/native-power.nix
    ../../modules/nixos/desktop/default.nix
    ../../modules/nixos/services/ssh/strict.nix
    ../../users/will/default.nix
    ./system.nix
    ../../modules/nixos/development/kubernetes.nix
    ../../modules/nixos/development/iac.nix
  ];

  system.stateVersion = "25.11";
}
