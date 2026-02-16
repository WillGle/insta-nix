{
  pkgs,
  lib,
  config,
  pkgsUnstable,
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
    kanshi
    wob
    xdg-utils

    # WM helpers
    dunst
    hyprpaper
    hyprlock
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

    # Extended Codecs
    faac
    faad2
    fdk_aac
    flac
    lame
    libmad
    libogg
    libvorbis
    opusTools
    libdvdcss
    libdvdread
    libdvdnav
    x264
    x265

    # GStreamer
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.gst-vaapi

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
    sddm-astronaut

    # Media apps
    evince
    guvcview
    mpv
    gthumb
    obs-studio
    sonic-visualiser
    vlc

    # Apps
    brave
    firefox
    gsimplecal
    libreoffice-fresh
    wpsoffice
    xournalpp
    zotero
    vscode

    # Shell & prompt
    bash
    gawk
    git
    gnome-console

    # Auth agents
    pantheon.pantheon-agent-polkit

    # Specific Versions
    pkgsUnstable.antigravity

    # Audit Tools (Rigidity)
    deadnix
    nixfmt-rfc-style
    statix
  ];
}
