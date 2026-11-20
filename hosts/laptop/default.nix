{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../base/default.nix
    ../../modules/system/maintenance
    ../../modules/system/hardware
    ../../modules/system/llm
    ../../modules/system/power
    ../../modules/system/gaming
    ../../modules/desktop/default.nix
    ../../modules/system/services/ssh/strict.nix
    ../../users/will/default.nix
    ./system.nix
    ../../modules/system/development
  ];

  system.stateVersion = "25.11";
}
