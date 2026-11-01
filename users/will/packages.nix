{ pkgs, pkgsUnstable, ... }:
{
  # Personal applications belong to the user profile. Genuinely system-wide
  # tools, services, and desktop integration live in environment.systemPackages
  # under hosts/<host>/system/packages.nix.
  home.packages = with pkgs; [
    pkgsUnstable.antigravity-ide
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
    lightworks-with-desktop
    pkgsUnstable.losslesscut-bin
    loupe
    pkgsUnstable.obs-studio
    rawtherapee
    vlc
    tauon
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
