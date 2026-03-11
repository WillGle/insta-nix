{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./storage.nix
    ./networking.nix

    ../../profiles/common/default.nix

    ../../profiles/hardware/amd-ryzen-laptop.nix

    ../../profiles/roles/desktop-hypr.nix
    ../../profiles/roles/workstation-apps.nix
    ../../profiles/roles/gaming.nix
  ];
}
