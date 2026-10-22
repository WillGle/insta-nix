{ pkgs, pkgsUnstable, ... }:
let
  antigravityIde = pkgsUnstable.callPackage ../../pkgs/antigravity-ide { };
  lightworksWithDesktop = pkgs.callPackage ../../pkgs/lightworks { };
in
{
  # Keep personal apps on the system PATH; host modules own hardware and services.
  environment.systemPackages = with pkgs; [
    antigravityIde
    pkgsUnstable.antigravity-cli

    # Editors & search
    neovim
    recoll
    zed-editor

    # Browsers
    brave
    firefox

    # Office & productivity
    gsimplecal
    pkgsUnstable.libreoffice-stable
    pkgsUnstable.obsidian
    wpsoffice
    pkgsUnstable.xournalpp
    pkgsUnstable.vscode

    # Media apps
    pkgsUnstable.darktable
    evince
    gthumb
    guvcview
    imv
    lightworksWithDesktop
    pkgsUnstable.losslesscut-bin
    loupe
    pkgsUnstable.obs-studio
    rawtherapee
    vlc
    pkgsUnstable.tauon
    wavpack

    # System GUI apps
    baobab
    gnome-disk-utility
    mission-center
    nautilus
    networkmanagerapplet
    pavucontrol
    pkgsUnstable.proton-vpn
    qpwgraph
  ];
}
