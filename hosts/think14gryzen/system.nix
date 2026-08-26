{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  # ryzen-smu upstream still calls cpuid_eax()/cpuid_ebx() bare; kernel >= 7.x
  # moved those helpers out of the headers smu.c pulls in transitively.
  ryzenSmuFixed = pkgsUnstable.linuxPackages_latest.ryzen-smu.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i '1i #include <asm/cpuid/api.h>' smu.c
    '';
  });

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

    # scx_lavd was tried here (2026-08-22) and REMOVED: measured -21% prefill
    # and relative jittery decode (27.9-31.9 vs a stable 33.2 t/s) on llama.cpp
    # Vulkan — latency-first scheduling starves the GPU submission thread.
    # EEVDF default wins for this box's throughput-first priorities.

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

  # Newer amdgpu MES/SMU/VCN blobs than the 25.11 snapshot; mkBefore so the
  # unstable copy wins path collisions against the stable default set.
  hardware.firmware = lib.mkBefore [ pkgsUnstable.linux-firmware ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Mesa stays on stable (the nixpkgs-25.11 default) for the whole system.
    # ba72b36 moved it to unstable 26.2 for llama.cpp throughput; that broke
    # four separate things because Mesa's driver .so files declare NO libdrm
    # dependency — no RPATH, no DT_NEEDED — and resolve those symbols from
    # whichever process dlopens them. Mesa 26.2 wants libdrm 2.4.134 while
    # every nixpkgs-25.11 application ships 2.4.129, so serving 26.2
    # system-wide meant: Steam's i686 client dead on GLX, CS2 SIGSEGV in
    # RADV, VA-API decode dead (libva ABI), and Chromium/Brave silently
    # losing GPU acceleration entirely ("undefined symbol:
    # amdgpu_va_manager_query_sw_info" -> EGL init fails -> --use-gl=disabled).
    # The 26.2 throughput win is preserved where it is actually safe: scoped
    # to llama.cpp in modules/nixos/llm.nix, which is built from pkgsUnstable
    # and therefore already carries the matching libdrm.
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
      # libva must match the Mesa that provides the VA driver; both are stable
      # now, so these stay stable too. Mixing them is what killed hardware
      # video decode (stable libva 2.22 looks for __vaDriverInit_1_22, unstable
      # Mesa 26.2 exports only __vaDriverInit_1_24).
      libva
      libva-utils
      libva-vdpau-driver
      mesa
      mesa.opencl
      # AMD OpenCL ICD. Originally for DaVinci Resolve (removed 2026-08-22);
      # kept for clinfo and any OpenCL consumer.
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
    # Mainline from unstable (7.2 as of 2026-08): ~1.5y of amdgpu, amd-pstate
    # (per-core EPP boost), and sched_ext maturity over the old 6.12 LTS pin.
    # The pin existed for ryzen-smu, which builds against 7.2 since 2026-04.
    kernelPackages = pkgsUnstable.linuxPackages_latest;
    extraModulePackages = [ ryzenSmuFixed ];

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
      # No VK_DRIVER_FILES override needed any more: the system Mesa is stable
      # 25.2.6 again, which is the RADV that CS2 actually runs on. The override
      # existed only to route around unstable Mesa 26.2 — see the note on
      # hardware.graphics above.
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
      # Already a transitive dependency of half the desktop; listed here purely
      # so `notify-send` lands on the interactive PATH. The scripts in this repo
      # do not read it from here — they pin it through writeShellApplication's
      # runtimeInputs, which is why they kept working while the shell had none.
      libnotify
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
      # Screen recording for the waybar button and Super+R. Picked over
      # wl-screenrec (which drags in a second ffmpeg, +31 MB) and
      # gpu-screen-recorder (whose KMS helper needs CAP_SYS_ADMIN): this one
      # adds 0.2 MB because it reuses the ffmpeg already here, and speaks the
      # same wlr-screencopy protocol grim does.
      wf-recorder
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
      # lmstudio dropped 2026-08-24: the llm-* belt (llmfit / llm-pull /
      # llm-list / llm-fit / llm-run) plus pi covers every role it filled, and
      # keeping it would mean a second package needing the scoped unstable
      # RADV override from modules/nixos/llm.nix. Models are untouched —
      # ~/.lmstudio/models is just the default path the scripts use, and
      # LLM_MODELS_DIR overrides it.
      stressapptest
      sysbench
      vulkan-tools
      vulkan-caps-viewer
      vkmark
      clinfo
      amdgpu_top
      radeontop
      # ROCm: diagnostics only. The HIP compute libraries (rocblas, hipblas,
      # hipblaslt, rocsolver, rocsparse, hipsparse, rocfft, hipfft, rocrand,
      # hiprand, rocprim, rocthrust, hipcub, miopen, rocm-bandwidth-test —
      # ~7.8 GiB of closure) were the "Tier A" runtime kept on 2026-06-07 for
      # local training. The 2026-08-22 verdict (docs/archive/rocm/README.md)
      # closed that lane: gfx1103 is not a supported ROCm target, training on
      # it is stochastic, and it moved to cloud GPUs; llama.cpp runs on Vulkan
      # (modules/nixos/llm.nix). Nothing on this host linked against those
      # libraries afterwards, so they were removed 2026-08-25. Re-adding is a
      # line here, cache-served. OpenCL (clr/clr.icd) stays in extraPackages.
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
      # GTK4 Bluetooth manager, and the only one surfaced in launchers — see
      # hosts/think14gryzen/home.nix, which hides blueman-manager's entry.
      # blueman-applet stays as the pairing agent (services.blueman in
      # modules/nixos/base.nix); this replaces only blueman-manager's window,
      # whose pair -> connect -> trust flow is three separate right-click menus
      # where GNOME's panel is one click. That split is not cosmetic:
      # connecting without pairing leaves an unencrypted link that
      # HID-over-GATT cannot use, and trusting it persists the dead entry.
      # modules/nixos/bluetooth.nix sweeps up whatever still slips through.
      #
      # Unstable, not stable, as a mitigation rather than a proven fix. Stable's
      # 0.6.5 hangs on startup often but not always: the process reaches "store
      # folder is:", then parks its main thread on a futex and never maps a
      # window, surviving a 60s wait and unaffected by GSK_RENDERER (cairo, gl,
      # vulkan all hang the same way). Other runs of the same binary open fine,
      # so this is a race, not a hard break, and the trigger was not pinned
      # down. 0.6.6 came up cleanly every time it was tried. Revisit if the
      # hang shows up again.
      pkgsUnstable.overskride

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
      pkgsUnstable.libreoffice-stable
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
      # pi coding agent — drives the local llama-server via the custom
      # provider in ~/.pi/agent/models.json (and Zed via pi-acp).
      pkgsUnstable.pi-coding-agent
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
