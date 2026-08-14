{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  # llama.cpp with the Vulkan backend, from nixpkgs-unstable (current build incl. the
  # RDNA3 Wave32 flash-attention path). Pinned via flake.lock -> reproducible &
  # persistent (part of the system closure, never GC'd). Measured fastest local-LLM
  # backend on the 780M: ~1.8x ollama's bundled engine (32 vs ~18 t/s decode, gemma-4B).
  # See docs/internal/LLM_BENCHMARK_20260607.md.
  llamaCppVulkan = pkgsUnstable.llama-cpp.override { vulkanSupport = true; };

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

  # Package a script asset the same way home.nix does: shellcheck runs at build
  # time, `set -euo pipefail` comes from the builder, and runtimeInputs are
  # pinned. The two privileged tools below are reached through a NOPASSWD sudo
  # rule, so they are exactly the ones that should not be the unlinted inline
  # heredocs they used to be.
  mkSystemScript =
    {
      name,
      dir ? ./assets/system-bin,
      runtimeInputs ? [ ],
      vars ? { },
      excludeShellChecks ? [ ],
    }:
    let
      source = dir + "/${name}";
      rendered = if vars == { } then source else pkgs.replaceVars source vars;
      body = lib.concatStringsSep "\n" (lib.drop 1 (lib.splitString "\n" (builtins.readFile rendered)));
    in
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      text = body;
    };

  # Shared by llm-fit and llm-run; referenced by store path, like the network
  # and screen-time libs.
  llmLib = ./assets/llm/lib/common.sh;

  hostToolPackages = [
    (mkSystemScript {
      name = "ryzenadj-profile";
      runtimeInputs = with pkgs; [ coreutils ];
    })

    (mkSystemScript {
      name = "toggle-battery-reserve";
      runtimeInputs = with pkgs; [ coreutils ];
    })

    # --- Optimal local-LLM stack: llama.cpp Vulkan (measured fastest on the 780M) ---
    # Provides llama-server (OpenAI-compatible API), llama-bench, llama-fit-params, llama-cli.
    llamaCppVulkan
    # llm-pull: ollama-like one-command fetch of a GGUF from HuggingFace into the local
    # model dir (prefers Unsloth UD quants, handles shards). `llm-pull <hf-repo> [quant]`.
    (mkSystemScript {
      name = "llm-pull";
      dir = ./assets/local-bin;
      runtimeInputs = with pkgs; [
        coreutils
        curl
        gnugrep
        gnused
        jq
      ];
    })
    # llm-fit: model-agnostic GTT-overflow check. `llm-fit <model.gguf> [ctx]` -> does it
    # fit the GPU? if not, the lightest KV-cache type that fixes it, or a GTT-raise hint.
    (mkSystemScript {
      name = "llm-fit";
      dir = ./assets/local-bin;
      vars = { llmLib = "${llmLib}"; };
      # PROG/FIT are read by the sourced lib; shellcheck cannot see across that.
      excludeShellChecks = [ "SC2034" ];
      runtimeInputs = with pkgs; [
        coreutils
        gawk
      ];
    })
    # llm-run: auto-sized, overflow-safe llama-server launcher. `llm-run <model.gguf> [ctx]`
    # picks the lightest KV that keeps FULL GPU offload (f16->q8_0->q4_0), -fa on, mmap.
    (mkSystemScript {
      name = "llm-run";
      dir = ./assets/local-bin;
      vars = { llmLib = "${llmLib}"; };
      excludeShellChecks = [ "SC2034" ];
      runtimeInputs = with pkgs; [ coreutils ];
    })
  ];
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

  # Passwordless sudo for approved power wrappers only.
  security.sudo.extraRules = [
    {
      users = [ "will" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/ryzenadj-profile";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/toggle-battery-reserve";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

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
              "bluez5.codecs" = [
                "sbc"
                "sbc_xq"
                "aac"
                "ldac"
                "aptx"
                "aptx_hd"
              ];
              "bluez5.roles" = [
                "a2dp_sink"
                "a2dp_source"
                "headset_head_unit"
                "headset_audio_gateway"
                "bap_sink"
                "bap_source"
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

  # Systemd services configuration
  systemd.services = {
    # Keep Lenovo battery reserve mode ON at boot.
    # Path discovery is dynamic inside toggle-battery-reserve.
    battery-reserve-default = {
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

    # Re-apply the default CPU power profile after boot because firmware
    # power management can overwrite RyzenAdj limits.
    cpu-default-power-profile = {
      description = "Set default CPU power profile";
      wantedBy = [ "graphical.target" ];
      wants = [ "power-profiles-daemon.service" ];
      after = [
        "systemd-modules-load.service"
        "power-profiles-daemon.service"
      ];
      script = ''
        /run/current-system/sw/bin/powerprofilesctl set power-saver
        /run/current-system/sw/bin/ryzenadj-profile power-saver
      '';
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

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

  powerManagement = {
    enable = true;
    resumeCommands = ''
      ${pkgs.coreutils}/bin/sleep 2
      current_profile="$(
        /run/current-system/sw/bin/powerprofilesctl get 2>/dev/null || echo power-saver
      )"
      case "$current_profile" in
        performance)
          /run/current-system/sw/bin/ryzenadj-profile performance
          ;;
        balanced)
          /run/current-system/sw/bin/ryzenadj-profile balanced
          ;;
        *)
          /run/current-system/sw/bin/ryzenadj-profile power-saver
          ;;
      esac
    '';
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
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_FONT_DPI = "144";
    QT_SCALE_FACTOR = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";
  };

  environment.systemPackages =
    hostToolPackages
    ++ (with pkgs; [
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
      # Full ROCm runtime/library stack (Tier A). Cache-served on the 25.11 pin
      # (no local compile); library-only so it dispatches no GPU kernels and
      # cannot trigger the gfx1103 MES-reset/logout lane. Do NOT set
      # nixpkgs.config.rocmSupport or HSA_OVERRIDE_GFX_VERSION globally (the
      # latter would break DaVinci's shared OpenCL ICD). gfx1103 is absent from
      # the default gpuTargets, so any ROCm *compute* stays NO-GO; LLM inference
      # uses Vulkan via llm-run (llama.cpp), not ROCm. See
      # docs/archive/rocm/ROCM_WORKLOG_20260607-113702.md.
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
      bind # dig / nslookup / host
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
