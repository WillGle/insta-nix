{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix

    ../../profiles/common/theme.nix
    ../../profiles/common/core.nix
    ../../profiles/common/i18n.nix
    ../../profiles/common/users-will.nix
    ../../profiles/common/services-base.nix
    ../../profiles/common/connectivity-base.nix

    ../../profiles/roles/desktop-hypr.nix
    ../../profiles/roles/workstation-apps.nix
  ];
}
