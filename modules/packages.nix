{
  pkgs,
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
    wl-clipboard
    wlr-randr
    wob
    xdg-utils
    foot

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
    usbutils
    wget
    imagemagick
    chafa
    zoxide
    fzf
    fd
    ripgrep

    # Shell & prompt
    bash
    gawk
    git
    gnome-console

    # Auth agents
    lxqt.lxqt-policykit

    # Specific Versions
    pkgsUnstable.antigravity

    # Audit Tools (Rigidity)
    deadnix
    nixfmt-rfc-style
    statix

    # Networking & Bluetooth
    bind
    networkmanagerapplet
    protonvpn-gui
    udiskie

    # Themes
    adwaita-icon-theme
    bibata-cursors
    sddm-astronaut
  ];
}
