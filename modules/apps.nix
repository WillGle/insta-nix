{ pkgs, ... }:
{
  # ───────── GUI Applications & Media ─────────
  environment.systemPackages = with pkgs; [
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
  ];
}
