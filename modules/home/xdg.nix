{ config, ... }:

{
  dconf.settings."org/gnome/desktop/default-applications/terminal" = {
    exec = "foot";
    "exec-arg" = "-e";
  };

  xdg = {
    enable = true;

    userDirs = {
      enable = true;
      desktop = "${config.home.homeDirectory}/Desktop";
      download = "${config.home.homeDirectory}/Downloads";
      templates = "${config.home.homeDirectory}/Templates";
      publicShare = "${config.home.homeDirectory}/Public";
      documents = "${config.home.homeDirectory}/Documents";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
        "x-scheme-handler/about" = "brave-browser.desktop";
        "x-scheme-handler/unknown" = "brave-browser.desktop";
        "x-scheme-handler/sgnl" = "org.signal.Signal.desktop";
        "x-scheme-handler/signalcaptcha" = "org.signal.Signal.desktop";
        "text/plain" = "code.desktop";
        "application/pdf" = "draw.desktop";

        "image/jpeg" = "org.gnome.Loupe.desktop";
        "image/png" = "org.gnome.Loupe.desktop";
        "image/webp" = "org.gnome.Loupe.desktop";
        "image/gif" = "org.gnome.Loupe.desktop";
        "image/bmp" = "org.gnome.Loupe.desktop";
        "image/tiff" = "org.gnome.Loupe.desktop";
        "application/wps-office.docx" = "wps-office-wps.desktop";
        "application/wps-office.xlsx" = "wps-office-et.desktop";
        "application/wps-office.pptx" = "wps-office-wpp.desktop";

        "video/mp4" = "vlc.desktop";
        "video/mpeg" = "vlc.desktop";
        "video/x-matroska" = "vlc.desktop";
        "video/webm" = "vlc.desktop";
        "video/x-flv" = "vlc.desktop";
        "video/quicktime" = "vlc.desktop";
        "video/x-msvideo" = "vlc.desktop";
        "video/x-ms-wmv" = "vlc.desktop";
        "video/ogg" = "vlc.desktop";
        "video/x-ms-asf" = "vlc.desktop";
        "video/3gpp" = "vlc.desktop";
        "video/x-ogm+ogg" = "vlc.desktop";

        "audio/flac" = "tauonmb.desktop";
        "audio/x-flac" = "tauonmb.desktop";
        "audio/wav" = "tauonmb.desktop";
        "audio/x-wav" = "tauonmb.desktop";
        "audio/mpeg" = "tauonmb.desktop";
        "audio/x-wavpack" = "tauonmb.desktop";
      };
    };
  };
}
