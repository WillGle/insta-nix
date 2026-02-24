{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Media tools/codecs
    ffmpeg-full
    ffmpegthumbnailer
    gnome-epub-thumbnailer
    libavif
    libheif
    v4l-utils

    # Extended Codecs
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

    # Audio
    alsa-utils
    pavucontrol
    qpwgraph

    # Media apps
    evince
    guvcview
    mpv
    gthumb
    obs-studio
    sonic-visualiser
    vlc

    # Apps
    brave
    firefox
    gsimplecal
    libreoffice-fresh
    wpsoffice
    xournalpp
    zotero
    vscode
  ];
}
