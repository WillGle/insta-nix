{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  bluemanWithoutApplet = pkgs.blueman.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      rm -f "$out/lib/systemd/user/blueman-applet.service"
      rm -f "$out/etc/xdg/autostart/blueman.desktop"
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
  # NixOS keeps Blueman's package, D-Bus integration, and mechanism service;
  # Home Manager owns the applet lifecycle for the Hyprland session. The
  # package's applet unit and XDG autostart entry are removed from the
  # system package so Home Manager is the only applet lifecycle owner.
  services.blueman.enable = lib.mkForce false;
  services.dbus.packages = [ bluemanWithoutApplet ];
  systemd.packages = [ bluemanWithoutApplet ];

  programs.wireshark.enable = true;

  environment.systemPackages =
    (with pkgs; [
      bluemanWithoutApplet
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
      # GUI model runner dropped 2026-08-24: the llm-* belt (llmfit / llm-pull /
      # llm-list / llm-fit / llm-run) plus pi covers every role it filled, and
      # keeping it would mean a second package needing the scoped unstable
      # RADV override from modules/nixos/llm.nix. Models are untouched —
      # /mnt/vault/lmstudio-models is the default path the scripts use, and
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
      # blueman-applet stays as the pairing agent (the NixOS package and
      # Home Manager user unit); this replaces only blueman-manager's window,
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
      nixd
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
