{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./storage.nix
    ./networking.nix

    ../../profiles/common/core.nix
    ../../profiles/common/i18n.nix
    ../../profiles/common/users-will.nix
    ../../profiles/common/services-base.nix
    ../../profiles/common/connectivity-base.nix

    ../../profiles/hardware/amd-ryzen-laptop.nix

    ../../profiles/roles/desktop-hypr.nix
    ../../profiles/roles/workstation-apps.nix
    ../../profiles/roles/gaming.nix
  ];
}
