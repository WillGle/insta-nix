{ pkgs, pkgsUnstable, ... }:
{
  # Personal applications belong to the user profile. Genuinely system-wide
  # tools, services, and desktop integration live in environment.systemPackages
  # under hosts/<host>/system/packages.nix.
  #
  # Self-updating GUI apps come from Flathub instead: Brave, Zed, VS Code,
  # Obsidian, Discord, LosslessCut, and Signal.
  home.packages = with pkgs; [
    pkgsUnstable.antigravity-ide
    pkgsUnstable.antigravity-cli

    # Editors & search
    neovim
    recoll

    # Browsers (Brave is installed from Flathub as com.brave.Browser)
    firefox

    # Office & productivity
    gsimplecal
    pkgsUnstable.libreoffice-stable
    wpsoffice
    pkgsUnstable.xournalpp

    # Media apps
    pkgsUnstable.darktable
    evince
    gthumb
    guvcview
    imv
    lightworks-with-desktop
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
