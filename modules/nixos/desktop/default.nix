{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  sddmTheme = pkgs.sddm-astronaut.override {
    themeConfig.Background = "/var/lib/sddm-wallpaper/background.jpg";
  };

  # Home Manager starts Fcitx; remove the competing XDG autostart launcher.
  # Keep core and addons on one package set for ABI compatibility.
  fcitx5WithoutAutostart = pkgsUnstable.callPackage ../../../pkgs/fcitx5 {
    inherit (config.i18n.inputMethod.fcitx5) addons;
  };
in
{
  services = {
    flatpak.enable = true;
    upower.enable = true;
    acpid.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
        theme = "${sddmTheme}/share/sddm/themes/sddm-astronaut-theme";
        extraPackages = with pkgs; [
          kdePackages.qtmultimedia
          kdePackages.qtsvg
          kdePackages.qtvirtualkeyboard
          kdePackages.qt5compat
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
      # Use upstream defaults for clocks, buffers, codecs, and device profiles.
      wireplumber = {
        enable = true;
        extraConfig = {
          "11-bluetooth-policy" = {
            "monitor.bluez.rules" = [
              {
                matches = [
                  {
                    "device.api" = "bluez5";
                  }
                ];
                actions = {
                  update-props = {
                    # Complete playback connections when only another profile is up.
                    "bluez5.auto-connect" = [ "a2dp_sink" ];
                  };
                };
              }
              {
                matches = [
                  {
                    "node.name" = "~bluez_output.*";
                  }
                ];
                actions = {
                  update-props = {
                    # Prefer Bluetooth playback without promoting sink monitors
                    # above physical microphones (source priorities start at 2000).
                    "priority.session" = 1500;
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
      addons = with pkgsUnstable; [
        fcitx5-bamboo
        fcitx5-gtk
        kdePackages.fcitx5-qt
        libsForQt5.fcitx5-qt
      ];
      waylandFrontend = true;
    };
  };

  i18n.inputMethod.package = lib.mkForce fcitx5WithoutAutostart;

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
    config.common."org.freedesktop.impl.portal.Wallpaper" = [ "gtk" ];
  };

  qt = {
    enable = true;
    style = "adwaita-dark";
  };

  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_FONT_DPI = "144";
    QT_SCALE_FACTOR = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";
  };
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
  ];
}
