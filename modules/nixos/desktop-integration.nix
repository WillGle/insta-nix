{ pkgs, ... }:
{
  services = {
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

  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_FONT_DPI = "144";
    QT_SCALE_FACTOR = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";
  };
}
