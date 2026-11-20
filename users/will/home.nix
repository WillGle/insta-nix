{ osConfig, ... }:

{
  imports = [
    ./packages.nix
    ../../modules/cli
  ];

  home = {
    username = osConfig.primaryUser.username;
    homeDirectory = "/home/${osConfig.primaryUser.username}";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
