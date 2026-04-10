{ pkgs, pkgsUnstable, ... }:
{
  # Ryzen laptop hardware + desktop + apps + gaming stack.
  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
      videoDrivers = [ "amdgpu" ];
    };

    # Power daemon (pick one).
    power-profiles-daemon.enable = true;

    # SSD trim.
    fstrim.enable = true;

    hypridle.enable = true;

    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
        theme = "sddm-astronaut-theme";
        extraPackages = with pkgs; [
          kdePackages.qtmultimedia
          kdePackages.qtsvg
          kdePackages.qtvirtualkeyboard
          kdePackages.qt5compat
          sddm-astronaut
        ];
      };
      defaultSession = "hyprland";
    };

    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = false;
      extraConfig.pipewire."92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.allowed-rates" = [
            44100
            48000
            88200
            96000
            176400
            192000
          ];
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 8192;
        };
      };
      wireplumber = {
        enable = true;
        extraConfig = {
          "10-policy" = {
            "wireplumber.settings" = {
              "device.restore-default-node" = true;
              "node.restore-default-node" = true;
            };
          };
          "11-bluetooth-policy" = {
            "wireplumber.settings" = {
              "bluetooth.autoswitch-to-headset-profile" = true;
            };
            "monitor.bluez.properties" = {
              "bluez5.enable-sbc-xq" = true;
              "bluez5.enable-msbc" = true;
              "bluez5.enable-hw-volume" = true;
              "bluez5.roles" = [
                "a2dp_sink"
                "a2dp_source"
                "headset_head_unit"
                "headset_audio_gateway"
              ];
            };
            "monitor.bluez.rules" = [
              {
                matches = [
                  {
                    "device.api" = "bluez5";
                  }
                ];
                actions = {
                  update-props = {
                    "priority.driver" = 5000;
                    "priority.session" = 5000;
                  };
                };
              }
            ];
          };
        };
      };
    };
  };

  services.udev.extraRules = ''
    # FiiO DAC (JadeAudio JA11 / SNOWSKY Melody) for WebHID access
    ATTRS{idVendor}=="2972", ATTRS{idProduct}=="0126", MODE="0666", GROUP="users"
  '';

  # Keep Lenovo battery reserve mode ON at boot.
  # Path discovery is dynamic inside toggle-battery-reserve.
  systemd.services.battery-reserve-default = {
    description = "Set Lenovo battery reserve mode to ON";
    wantedBy = [ "multi-user.target" ];
    wants = [ "systemd-udev-settle.service" ];
    after = [
      "systemd-modules-load.service"
      "systemd-udev-settle.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/toggle-battery-reserve on --wait 45";
      StandardOutput = "journal";
      StandardError = "journal";
    };
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

    kernelParams = [ "amd_pstate=active" ];
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
    };
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 37;
    priority = 100;
  };

  powerManagement.enable = true;

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };

  security.rtkit.enable = true;

  programs = {
    hyprland.enable = true;

    steam = {
      enable = true;
      # Keep firewall surface minimal by default.
      # Open ports explicitly in host modules when remote play/server is needed.
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
    };

    gamemode.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = false;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        qt6Packages.fcitx5-unikey
        fcitx5-gtk
        libsForQt5.fcitx5-qt
      ];
      waylandFrontend = true;
    };
  };

  environment.sessionVariables = {
    QT_FONT_DPI = "144";
    QT_SCALE_FACTOR = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";
  };

  environment.systemPackages =
    (with pkgs; [
      adwaita-icon-theme
      bibata-cursors
      sddm-astronaut

      # Wayland & WM helpers
      brightnessctl
      cliphist
      dunst
      grim
      hyprlock
      hyprpaper
      kanshi
      playerctl
      slurp
      sxhkd
      wl-clipboard
      wlr-randr
      wob
      wofi
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
      htop
      imagemagick
      jq
      matugen
      lm_sensors
      linuxPackages.cpupower
      nvtopPackages.amd
      p7zip
      poppler-utils
      ripgrep
      ryzen-monitor-ng
      pkgsUnstable.lmstudio
      pkgsUnstable.ollama-vulkan
      vulkan-tools
      vulkan-caps-viewer
      clinfo
      amdgpu_top
      radeontop
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
      libreoffice-fresh
      wpsoffice
      xournalpp
      zotero
      vscode
      calibre

      # Media apps
      evince
      gthumb
      guvcview
      obs-studio
      sonic-visualiser
      vlc
      strawberry
      wavpack

      # System GUI apps
      gnome-console
      gnome-disk-utility
      mission-center
      nautilus
      networkmanagerapplet
      pavucontrol
      protonvpn-gui
      qpwgraph

      # Media tools & codecs
      ffmpeg-full
      ffmpegthumbnailer
      gnome-epub-thumbnailer
      libavif
      libheif
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
      pkgsUnstable.antigravity
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
