{
  pkgs,
  pkgsUnstable,
  ...
}:
{
  # ───────── CLI Tools & System Utilities ─────────
  environment.systemPackages = with pkgs; [
    # Wayland & WM helpers
    brightnessctl
    cliphist
    dunst
    grim
    hyprlock
    hyprpaper
    playerctl
    slurp
    wl-clipboard
    wlr-randr
    wob
    wofi
    xdg-utils

    # CLI utilities
    btop
    chafa
    eza
    fastfetch
    fd
    gawk
    htop
    imagemagick
    jq
    lm_sensors
    p7zip
    poppler-utils
    ripgrep
    stress-ng
    tree
    unzip
    wget
    xz
    zip
    zstd

    # Filesystem
    dosfstools
    exfatprogs
    ntfs3g
    pciutils
    udiskie
    usbutils

    # Shell & version control
    bash
    git

    # Networking (CLI)
    bind

    # Auth agents
    lxqt.lxqt-policykit

    # Nix audit tools
    deadnix
    nixfmt-rfc-style
    statix

    # Pinned versions
    pkgsUnstable.antigravity
    pkgsUnstable.ryzenadj
  ];
}
