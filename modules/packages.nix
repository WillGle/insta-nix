{
  pkgs,
  pkgsUnstable,
  pkgs24_11,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # Wayland & desktop
    brightnessctl
    grim
    mission-center
    slurp
    waybar
    wl-clipboard
    wlr-randr
    wob
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
    btop
    cliphist
    dosfstools
    exfatprogs
    eza
    fastfetch
    gnome-disk-utility
    htop
    jq
    lm_sensors
    nautilus
    ntfs3g
    pciutils
    playerctl
    pkgsUnstable.ryzenadj
    poppler-utils
    stress-ng
    tree
    udiskie
    usbutils
    wget

    # Media tools/codecs
    ffmpeg-full
    ffmpegthumbnailer
    gnome-epub-thumbnailer
    libavif
    libheif
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
    evince
    guvcview
    mpv
    nomacs
    obs-studio
    sonic-visualiser
    vlc

    # Apps (Restored for stability)
    brave
    discord
    firefox
    gsimplecal
    libreoffice-fresh
    obsidian
    signal-desktop
    vscode
    wpsoffice
    xournalpp
    zotero

    # Shell & prompt
    bash
    fish
    gawk
    git
    gnome-console
    starship

    # Auth agents
    pantheon.pantheon-agent-polkit

    # Specific Versions
    pkgsUnstable.antigravity
    pkgs24_11.deadbeef

    # Audit Tools (Rigidity)
    deadnix
    nixfmt-rfc-style
    statix
  ];
}
