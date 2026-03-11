{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix

    ../../profiles/common/default.nix

    ../../profiles/roles/desktop-hypr.nix
    ../../profiles/roles/workstation-apps.nix
  ];
}
