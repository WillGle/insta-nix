{ config, pkgs, ... }:

{
  home.username = "will";
  home.homeDirectory = "/home/will";
  home.stateVersion = "25.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
