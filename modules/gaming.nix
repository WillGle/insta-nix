{
  pkgs,
  lib,
  config,
  ...
}:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.gamemode.enable = true;

  # Gaming tools and helpers.
  environment.systemPackages = with pkgs; [
    mesa-demos
    steam-run
    mangohud
  ];
}
