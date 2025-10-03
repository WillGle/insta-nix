{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Wayland & desktop
    alacritty
    brightnessctl
    mission-center
    waybar

    # WM helpers
    dunst
    hyprland
    hyprpaper
    hyprshot
    rofi-wayland
    sway
    swayidle
    swaylock
    wofi

    # Utilities
    acpid
    poppler_utils
    ffmpegthumbnailer
    gnome-epub-thumbnailer
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
    wl-clipboard
    wob
    xdg-utils
    grim
    slurp
    udiskie
    dosfstools
    exfatprogs
    ntfs3g
    ffmpeg
    v4l-utils
    libheif
    libavif
    wlr-randr

    # Audio & network
    alsa-utils
    bind
    blueman
    networkmanagerapplet
    pavucontrol
    pipewire
    protonvpn-gui
    upower
    pulseaudio

    # SDDM themes
    catppuccin-sddm
    sddm-astronaut
    sddm-chili-theme
    sddm-sugar-dark

    # Apps
    adwaita-icon-theme
    brave
    deadbeef
    docker
    firefox
    gsimplecal
    obs-studio
    obsidian
    signal-desktop
    vscode
    steam
    wpsoffice
    vlc
    gnome-disk-utility
    xournalpp
    libreoffice-fresh
    guvcview
    gthumb
    nomacs
    evince

    # Gaming tools
    mesa-demos
    vulkan-tools
    libva-utils
    steam-run
    mangohud

    # Shell & prompt
    fish
    git
    gnome-console
    starship
    bash
    gawk

    # Cursors
    bibata-cursors
  ];
}
