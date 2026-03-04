{ pkgs, pkgsUnstable, ... }:
{
  environment.systemPackages =
    (with pkgs; [
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
      volctl
      wl-clipboard
      wlr-randr
      wob
      wofi
      xdg-utils

      # CLI utilities
      btop
      chafa
      eza
      fastfetch
      fd
      gawk
      htop
      imagemagick
      jq
      lm_sensors
      p7zip
      poppler-utils
      ripgrep
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

      # Media apps
      evince
      gthumb
      guvcview
      obs-studio
      sonic-visualiser
      vlc

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
