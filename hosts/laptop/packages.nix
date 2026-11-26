{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
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
    # ROCm diagnostics only: iGPU is unsupported for training.
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
    usbutils
    bluez-tools

    # Shell & version control
    bash
    git
    gh
    gnumake

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
}
