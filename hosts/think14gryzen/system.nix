{ pkgs, pkgsUnstable, ... }:
let
  # llama.cpp with the Vulkan backend, from nixpkgs-unstable (current build incl. the
  # RDNA3 Wave32 flash-attention path). Pinned via flake.lock -> reproducible &
  # persistent (part of the system closure, never GC'd). Measured fastest local-LLM
  # backend on the 780M: ~1.8x ollama's bundled engine (32 vs ~18 t/s decode, gemma-4B).
  # See docs/internal/LLM_BENCHMARK_20260607.md.
  llamaCppVulkan = pkgsUnstable.llama-cpp.override { vulkanSupport = true; };

  hostToolPackages = [
    (pkgs.writeShellScriptBin "ryzenadj-profile" ''
      set -euo pipefail

      PROFILE="''${1:-}"

      usage() {
        echo "Usage: ryzenadj-profile [performance|balanced|power-saver]" >&2
      }

      case "$PROFILE" in
        performance)
          # Disable scheduler autogroup for better throughput (desktop interactivity tradeoff accepted)
          echo 0 > /proc/sys/kernel/sched_autogroup_enabled || true
          exec /run/current-system/sw/bin/ryzenadj \
            --stapm-limit=48000 \
            --fast-limit=64000 \
            --slow-limit=60000 \
            --tctl-temp=98 \
            --apu-skin-temp=45 \
            --vrm-current=90000 \
            --vrmmax-current=110000 \
            --max-performance
          ;;

        balanced)
          echo 1 > /proc/sys/kernel/sched_autogroup_enabled || true
          exec /run/current-system/sw/bin/ryzenadj \
            --stapm-limit=28000 \
            --fast-limit=28000 \
            --slow-limit=28000 \
            --tctl-temp=85
          ;;

        power-saver)
          echo 1 > /proc/sys/kernel/sched_autogroup_enabled || true
          exec /run/current-system/sw/bin/ryzenadj \
            --stapm-limit=10000 \
            --fast-limit=10000 \
            --slow-limit=10000 \
            --tctl-temp=65 \
            --power-saving
          ;;

        *)
          usage
          exit 2
          ;;
      esac
    '')

    (pkgs.writeShellScriptBin "toggle-battery-reserve" ''
      set -euo pipefail

      CMD="''${1:-toggle}"
      WAIT_SECONDS=0
      NODE_GLOB="/sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode"
      NODE=""

      if [ "$#" -gt 0 ]; then
        shift
      fi

      usage() {
        echo "Usage: toggle-battery-reserve [status|on|off|toggle] [--wait SECONDS]" >&2
      }

      log() {
        echo "[toggle-battery-reserve] $*" >&2
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --wait)
            if [ "$#" -lt 2 ]; then
              usage
              exit 2
            fi
            WAIT_SECONDS="$2"
            shift 2
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            usage
            exit 2
            ;;
        esac
      done

      if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
        log "invalid --wait value: $WAIT_SECONDS"
        exit 2
      fi

      find_node_once() {
        local candidate
        for candidate in $NODE_GLOB; do
          if [ -f "$candidate" ]; then
            printf "%s\n" "$candidate"
            return 0
          fi
        done
        return 1
      }

      resolve_node() {
        if [ -n "$NODE" ] && [ -f "$NODE" ]; then
          printf "%s\n" "$NODE"
          return 0
        fi

        local deadline now candidate
        deadline=$(( $(date +%s) + WAIT_SECONDS ))

        while :; do
          if candidate="$(find_node_once)"; then
            NODE="$candidate"
            printf "%s\n" "$NODE"
            return 0
          fi

          now=$(date +%s)
          if [ "$now" -ge "$deadline" ]; then
            log "conservation_mode node not found (searched $NODE_GLOB)"
            return 1
          fi
          sleep 1
        done
      }

      read_state_raw() {
        local node state

        if ! node="$(resolve_node)"; then
          return 1
        elif ! state="$(cat "$node" 2>/dev/null)"; then
          log "failed to read $node"
          return 1
        fi

        case "$state" in
          0|1) printf "%s\n" "$state" ;;
          *)
            log "unexpected value '$state' in $node"
            return 1
            ;;
        esac
      }

      write_state_raw() {
        local target="$1"
        local node

        if ! node="$(resolve_node)"; then
          return 1
        fi

        if ! printf "%s" "$target" > "$node" 2>/dev/null; then
          log "failed to write $target to $node"
          return 1
        fi
      }

      print_state_word() {
        local raw="$1"
        case "$raw" in
          1) echo "on" ;;
          0) echo "off" ;;
          *) echo "unknown" ;;
        esac
      }

      case "$CMD" in
        status)
          if RAW_STATE="$(read_state_raw)"; then
            print_state_word "$RAW_STATE"
            exit 0
          fi
          echo "unknown"
          exit 1
          ;;

        on)
          if ! RAW_STATE="$(read_state_raw)"; then
            exit 1
          fi
          if [ "$RAW_STATE" != "1" ]; then
            write_state_raw "1" || exit 1
          fi
          echo "on"
          ;;

        off)
          if ! RAW_STATE="$(read_state_raw)"; then
            exit 1
          fi
          if [ "$RAW_STATE" != "0" ]; then
            write_state_raw "0" || exit 1
          fi
          echo "off"
          ;;

        toggle)
          if ! RAW_STATE="$(read_state_raw)"; then
            exit 1
          fi

          if [ "$RAW_STATE" = "1" ]; then
            write_state_raw "0" || exit 1
            echo "off"
          else
            write_state_raw "1" || exit 1
            echo "on"
          fi
          ;;

        *)
          usage
          exit 2
          ;;
      esac
    '')

    # --- Optimal local-LLM stack: llama.cpp Vulkan (measured fastest on the 780M) ---
    # Provides llama-server (OpenAI-compatible API), llama-bench, llama-fit-params, llama-cli.
    llamaCppVulkan
    # llm-pull: ollama-like one-command fetch of a GGUF from HuggingFace into the local
    # model dir (prefers Unsloth UD quants, handles shards). `llm-pull <hf-repo> [quant]`.
    (pkgs.writeShellScriptBin "llm-pull" (builtins.readFile ./assets/local-bin/llm-pull))
    # llm-fit: model-agnostic GTT-overflow check. `llm-fit <model.gguf> [ctx]` -> does it
    # fit the GPU? if not, the lightest KV-cache type that fixes it, or a GTT-raise hint.
    (pkgs.writeShellScriptBin "llm-fit" (builtins.readFile ./assets/local-bin/llm-fit))
    # llm-run: auto-sized, overflow-safe llama-server launcher. `llm-run <model.gguf> [ctx]`
    # picks the lightest KV that keeps FULL GPU offload (f16->q8_0->q4_0), -fa on, mmap.
    (pkgs.writeShellScriptBin "llm-run" (builtins.readFile ./assets/local-bin/llm-run))
  ];
in
{
  # Ryzen laptop hardware + desktop + apps + gaming stack.
  programs.fish.enable = true;

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

    hypridle.enable = true;
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
              "bluez5.codecs" = [ "sbc" "sbc_xq" "aac" "ldac" "aptx" "aptx_hd" ];
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

  # Re-apply the default CPU power profile after boot because firmware
  # power management can overwrite RyzenAdj limits.
  systemd.services.cpu-default-power-profile = {
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
  systemd.services.NetworkManager-wait-online.enable = false;

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
    hostToolPackages
    ++ (with pkgs; [
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
      neovim
      playerctl
      (rofi.override { plugins = [ rofi-calc rofi-emoji ]; })
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
      loupe
      pkgsUnstable.obs-studio
      rawtherapee
      pkgsUnstable.sonic-visualiser
      vlc
      pkgsUnstable.strawberry
      wavpack
      pkgsUnstable.davinci-resolve

      # System GUI apps
      gnome-disk-utility
      mission-center
      nautilus
      networkmanagerapplet
      pavucontrol
      pkgsUnstable.proton-vpn
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
