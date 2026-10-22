{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  bluemanWithoutApplet = pkgs.callPackage ../../../pkgs/blueman { };
in
{
  # NixOS owns Blueman's D-Bus integration and mechanism service.
  # Remove competing launchers so Home Manager alone starts the applet.
  services.blueman.enable = lib.mkForce false;
  services.dbus.packages = [ bluemanWithoutApplet ];
  systemd.packages = [ bluemanWithoutApplet ];

  programs.wireshark.enable = true;

  environment.systemPackages = with pkgs; [
    bluemanWithoutApplet
    adwaita-icon-theme
    bibata-cursors
    brightnessctl
    cliphist
    dunst
    grim
    hyprlock
    hyprpaper
    # Expose notify-send on the interactive PATH; scripts pin their own copy.
    libnotify
    playerctl
    (rofi.override {
      plugins = [
        rofi-calc
        rofi-emoji
      ];
    })
    rofi-power-menu
    slurp
    # Reuse the existing ffmpeg for recording without a privileged KMS helper.
    wf-recorder
    wl-clipboard
    wlr-randr
    xdg-utils

    # CLI utilities
    btop
    chafa
    curl
    eza
    fastfetch
    fd
    gawk
    gdu
    glmark2
    htop
    imagemagick
    jq
    matugen
    lm_sensors
    phoronix-test-suite
    linuxPackages.cpupower
    nvtopPackages.amd
    p7zip
    poppler-utils
    ripgrep
    ryzen-monitor-ng
    s-tui
    stressapptest
    sysbench
    vulkan-tools
    vulkan-caps-viewer
    vkmark
    clinfo
    amdgpu_top
    radeontop
    # ROCm diagnostics only: gfx1103 is unsupported for training.
    # llama.cpp uses Vulkan; OpenCL remains in graphics.extraPackages.
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
    rocmPackages.rocm-runtime
    rocmPackages.amdsmi
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
    bluez-tools
    # Use patched Overskride to pair and save trust before connecting.
    # Blueman remains the pairing agent; home.nix hides its manager.
    (pkgsUnstable.callPackage ../../../pkgs/overskride { })

    # Shell & version control
    bash
    git
    gh

    # Packet capture
    tcpdump
    termshark
    ngrep
    tcpflow

    # Network scanning
    nmap
    arp-scan
    whois
    hping
    macchanger

    # Network diagnostics
    bind
    mtr
    traceroute
    netcat-gnu
    socat
    iperf
    ethtool
    ipcalc

    # Traffic monitoring
    bmon
    iftop
    nload
    vnstat

    # Routing and firewall tools
    iproute2
    nettools
    bridge-utils
    openvswitch
    conntrack-tools
    nftables

    # VPN and overlay tools
    wireguard-tools
    openvpn
    dnsmasq

    # Tracing tools
    strace
    ltrace
    lsof
    sysstat
    numactl
    perf

    impala

    # Auth agents
    lxqt.lxqt-policykit

    # Nix audit tools
    nixd
    deadnix
    nixfmt
    statix

    # Media tools & codecs
    ffmpeg-full
    ffmpegthumbnailer
    gnome-epub-thumbnailer
    libavif
    libheif
    mediainfo
    mediainfo-gui
    spek
    v4l-utils
    alsa-utils

    # Extended codecs
    faac
    faad2
    fdk_aac
    flac
    lame
    libmad
    libogg
    libvorbis
    opus-tools
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

    # Gaming tools and helpers
    mesa-demos
    steam-run
    mangohud
  ];

  fonts = {
    enableDefaultPackages = true;
    fontconfig.enable = true;

    packages = with pkgs; [
      nerd-fonts.meslo-lg
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono

      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji

      roboto
      unifont
      freefont_ttf
      ipaexfont
      corefonts
    ];

    fontconfig.defaultFonts = {
      monospace = [
        "JetBrainsMono Nerd Font"
        "FiraCode Nerd Font"
      ];
      sansSerif = [
        "Noto Sans"
        "Roboto"
      ];
      serif = [ "Noto Serif" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
