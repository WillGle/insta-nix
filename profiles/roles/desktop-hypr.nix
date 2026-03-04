{ pkgs, lib, ... }:
{
  options.theme = {
    colors = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        base = "#0d1117";
        mantle = "#161b22";
        text = "#f0f6fc";
        subtext = "#8b949e";
        accent = "#58a6ff";
        success = "#3fb950";
        warning = "#d29922";
        error = "#f85149";
        purple = "#bc8cff";
        cyan = "#39c5cf";
      };
      description = "System color palette";
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      adwaita-icon-theme
      bibata-cursors
      sddm-astronaut
    ];

    environment.sessionVariables = {
      QT_FONT_DPI = "144";
      QT_SCALE_FACTOR = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
    };

    security.rtkit.enable = true;

    services = {
      xserver = {
        enable = true;
        xkb.layout = "us";
      };

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

    programs.hyprland = {
      enable = true;
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
  };
}
