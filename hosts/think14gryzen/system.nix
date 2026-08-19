{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  # Lightworks wrapper that adds the official .desktop file and icon,
  # missing from nixpkgs buildFHSUserEnv by default.
  lightworksWithDesktop = pkgs.symlinkJoin {
    name = "lightworks-with-desktop";
    paths = [
      pkgs.lightworks
      (pkgs.runCommand "lightworks-desktop" { lw = pkgs.lightworks; } ''
        mkdir -p $out/share/applications $out/share/icons/hicolor/512x512/apps
        rootfs=$(grep -o '/nix/store/[^" ]*-fhsenv-rootfs' $lw/bin/lightworks | head -n1)
        if [ -n "$rootfs" ] && [ -f "$rootfs/usr/share/lightworks/Icons/App.png" ]; then
          cp "$rootfs/usr/share/lightworks/Icons/App.png" $out/share/icons/hicolor/512x512/apps/lightworks.png
        fi
        cat > $out/share/applications/lightworks.desktop <<EOF
[Desktop Entry]
Version=1.0
Name=Lightworks
GenericName=Video Editor
Comment=Cross-platform film & video editor
Exec=lightworks
Icon=lightworks
Terminal=false
Type=Application
Categories=AudioVideo;AudioVideoEditing;
StartupWMClass=Ntcardvt
EOF
      '')
    ];
  };
in
{
  # Ryzen laptop hardware + desktop + apps + gaming stack.

  # Threat model (intentional):
  # `will` is the primary owner-admin account for this personal machine,
  # so near-root capabilities are accepted for operational convenience.
  users.users.will = {
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "seat"
      "audio"
      "bluetooth"
      "docker"
      "render"
      "wireshark"
    ];
  };

  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
      videoDrivers = [ "amdgpu" ];
    };

    # iOS USB multiplexing daemon
    usbmuxd.enable = true;

    # Power daemon (pick one).
    power-profiles-daemon.enable = true;

    # SSD trim.
    fstrim.enable = true;

    # Idle management is off by design: the hypridle config was removed, and
    # the daemon exits without one, which would surface as a failed unit in
    # the waybar systemd module rather than as silent inaction.
    hypridle.enable = false;

    # Suspend on lid close when running on battery; keep awake on AC or when docked.
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
    cpupower-gui.enable = true;
    openlogi.enable = true;

    udev.extraRules = ''
      # FiiO DAC (JadeAudio JA11 / SNOWSKY Melody) for WebHID access
      ATTRS{idVendor}=="2972", ATTRS{idProduct}=="0126", MODE="0666", GROUP="users"
    '';
  };

  systemd.services = {
    # Drop the ~5.4s boot blocker on the critical chain: docker is the only
    # consumer of network-online.target and brings up its own docker0 bridge,
    # so waiting for full connectivity before graphical.target buys nothing.
    NetworkManager-wait-online.enable = false;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
      libva
      libva-utils
      libva-vdpau-driver
      mesa
      mesa.opencl
      # Restore the AMD OpenCL ICD so DaVinci Resolve can see the 780M again.
      rocmPackages.clr
      rocmPackages.clr.icd
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      libva
      libva-utils
      libva-vdpau-driver
    ];
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelParams = [
      "amd_pstate=active"
      "transparent_hugepage=always"
      "ttm.pages_limit=5767168"
    ];
    kernelModules = [
      "msr"
      "ryzen_smu"
    ];
    kernelPackages = pkgs.linuxPackages_6_12;
    extraModulePackages = [ pkgs.linuxPackages_6_12.ryzen-smu ];

    initrd.kernelModules = [ "amdgpu" ];
    blacklistedKernelModules = [ "lenovo_wmi_gamezone" ];

    kernel.sysctl = {
      # zram-friendly swapping (tune 10-30).
      "vm.swappiness" = 20;
      # zram is per-page CPU-decompressed: disable swap readahead so one fault
      # doesn't decompress 8 pages to serve 1. Recommended for compressed RAM swap.
      "vm.page-cluster" = 0;
    };
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 37;
    priority = 100;
  };

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
    storageDriver = "overlay2";
  };

  security.rtkit.enable = true;

  programs = {
    fish.enable = true;
    wireshark.enable = true;
    hyprland.enable = true;

    steam = {
      enable = true;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
    };

    gamemode.enable = true;
  };

  environment.systemPackages =
    (with pkgs; [
      adwaita-icon-theme
      bibata-cursors
      sddm-astronaut

      # Wayland & Qt helpers
      qt5.qtwayland
      qt6.qtwayland
      xorg.xcbutilcursor
      brightnessctl
      cliphist
      dunst
      grim
      hyprlock
      hyprpaper
      neovim
      recoll
      zed-editor
      playerctl
      (rofi.override {
        plugins = [
          rofi-calc
          rofi-emoji
        ];
      })
      rofi-power-menu
      slurp
      sxhkd
      wl-clipboard
      wlr-randr
      xdg-utils

      # CLI utilities
      btop
      chafa
      cpupower-gui
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
      pkgsUnstable.lmstudio
      stressapptest
      sysbench
      vulkan-tools
      vulkan-caps-viewer
      vkmark
      clinfo
      amdgpu_top
      radeontop
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
      rocmPackages.rocm-runtime
      rocmPackages.amdsmi
      rocmPackages.rocblas
      rocmPackages.hipblas
      rocmPackages.hipblaslt
      rocmPackages.rocsolver
      rocmPackages.rocsparse
      rocmPackages.hipsparse
      rocmPackages.rocfft
      rocmPackages.hipfft
      rocmPackages.rocrand
      rocmPackages.hiprand
      rocmPackages.rocprim
      rocmPackages.rocthrust
      rocmPackages.hipcub
      rocmPackages.miopen
      rocmPackages.rocm-bandwidth-test
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

      # Shell & version control
      bash
      git

      # Networking — packet capture & protocol analysis
      tcpdump
      wireshark
      termshark
      ngrep
      tcpflow

      # Networking — scanning & recon
      nmap
      arp-scan
      whois
      hping
      macchanger

      # Networking — diagnostics & troubleshooting
      bind
      mtr
      traceroute
      netcat-gnu
      socat
      iperf
      ethtool
      ipcalc

      # Networking — bandwidth & traffic monitoring
      bmon
      iftop
      nload
      vnstat

      # Networking — core stack (routing, bridges, namespaces, firewall)
      iproute2
      nettools
      bridge-utils
      openvswitch
      conntrack-tools
      nftables

      # Networking — VPN / overlay / virtual networking
      wireguard-tools
      openvpn
      dnsmasq

      # Deep Linux tracing & observability
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
      deadnix
      nixfmt-rfc-style
      statix

      # Browsers
      brave
      firefox

      # Office & productivity
      gsimplecal
      pkgsUnstable.libreoffice-fresh
      wpsoffice
      pkgsUnstable.xournalpp
      pkgsUnstable.zotero
      pkgsUnstable.vscode
      pkgsUnstable.calibre

      # Media apps
      pkgsUnstable.darktable
      evince
      gthumb
      guvcview
      imv
      lightworksWithDesktop
      pkgsUnstable.losslesscut-bin
      loupe
      pkgsUnstable.obs-studio
      rawtherapee
      vlc
      pkgsUnstable.tauon
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
      pkgsUnstable.waypaper

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

      # Gaming tools and helpers
      mesa-demos
      steam-run
      mangohud
    ])
    ++ [
      pkgsUnstable.antigravity-ide
      pkgsUnstable.antigravity-cli
      pkgsUnstable.ryzenadj
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
