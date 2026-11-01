_:

{
  imports = [
    ./packages.nix
    ../../modules/home/shell/default.nix
    ../../modules/home/terminal/default.nix
    ../../modules/home/xdg.nix
  ];

  home = {
    username = "will";
    homeDirectory = "/home/will";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
