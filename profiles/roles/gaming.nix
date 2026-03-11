{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    # Keep firewall surface minimal by default.
    # Open ports explicitly in host modules when remote play/server is needed.
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
  };

  programs.gamemode.enable = true;

  # Gaming tools and helpers.
  environment.systemPackages = with pkgs; [
    mesa-demos
    steam-run
    mangohud
  ];
}
