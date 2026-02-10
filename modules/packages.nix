{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Wayland & desktop
    brightnessctl
    mission-center
    waybar
    wlr-randr
    wl-clipboard
    wob
    grim
    slurp
    xdg-utils

    # WM helpers
    dunst
    hyprpaper
    hyprshot
    sway
    swayidle
    swaylock
    wofi

    # System utilities
    cliphist
    eza
    fastfetch
    htop
    jq
    lm_sensors
    nautilus
    pciutils
    playerctl
    usbutils
    wget
    udiskie
    dosfstools
    exfatprogs
    ntfs3g
    gnome-disk-utility
    poppler-utils
    tree

    # Media tools/codecs
    ffmpeg-full
    ffmpegthumbnailer
    gnome-epub-thumbnailer
    libheif
    libavif
    v4l-utils

    # Audio
    alsa-utils
    pavucontrol
    qpwgraph

    # Networking & Bluetooth
    bind
    networkmanagerapplet
    protonvpn-gui

    # Themes
    adwaita-icon-theme
    bibata-cursors

    # SDDM themes
    sddm-astronaut
    sddm-chili-theme
    sddm-sugar-dark

    # Media apps
    sonic-visualiser
    obs-studio
    mpv
    vlc
    guvcview
    nomacs
    evince

    # Apps
    brave
    discord
    firefox
    gsimplecal
    obsidian
    signal-desktop
    vscode
    wpsoffice
    xournalpp
    libreoffice-fresh
    zotero

    # Shell & prompt
    fish
    git
    gnome-console
    starship
    bash
    gawk
  ];
}
