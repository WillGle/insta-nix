{ config, pkgs, ... }:

{
  home.username = "will";
  home.homeDirectory = "/home/will";
  home.stateVersion = "25.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ───────── Fish Shell ─────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Suppress default fish welcome message
      set fish_greeting

      # Enable Vietnamese input environment for fcitx5
      set -xU INPUT_METHOD fcitx

      # Run fastfetch at shell startup
      fastfetch
    '';
    shellAliases = {
      ll = "eza -la --icons";
      gs = "git status";
      ".." = "cd ..";
    };
  };

  # ───────── Starship Prompt ─────────
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      format = "[](#001f3f)\$username[](#001f3f)\$directory[](#004080)\$git_branch\$git_status[](black)\$python\$nodejs[](#ffffff)";

      username = {
        style_user = "bold white";
        format = "[ $user ]($style)";
        show_always = true;
      };
      directory = {
        style = "bold white";
        format = "[ $path ]($style)";
      };
      git_branch = {
        symbol = "";
        style = "bold yellow";
        format = "[ $symbol $branch ]($style)";
      };
      git_status = {
        style = "green";
        format = "[$all_status]($style)";
      };
      python = {
        symbol = "";
        style = "yellow";
        format = "[ $symbol $version ]($style)";
      };
      nodejs = {
        symbol = "";
        style = "green";
        format = "[ $symbol $version ]($style)";
      };
    };
  };

  # ───────── Direnv ─────────
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ───────────────────────────────────────────────────────────────
  # Phase 3: Desktop Environment
  # ───────────────────────────────────────────────────────────────

  # ───────── Hyprland ─────────
  xdg.configFile."hypr/hyprland.conf".source    = ./dotfiles/hypr/hyprland.conf;
  xdg.configFile."hypr/hyprpaper.conf".source   = ./dotfiles/hypr/hyprpaper.conf;
  xdg.configFile."hypr/hyprlock.conf".source    = ./dotfiles/hypr/hyprlock.conf;
  xdg.configFile."hypr/hypridle.conf".source    = ./dotfiles/hypr/hypridle.conf;
  xdg.configFile."hypr/autostart.conf" = {
    source     = ./dotfiles/hypr/autostart.conf;
    executable = true;
  };
  xdg.configFile."hypr/toggle_waybar.sh" = {
    source     = ./dotfiles/hypr/toggle_waybar.sh;
    executable = true;
  };
  xdg.configFile."hypr/rotate_select.sh" = {
    source     = ./dotfiles/hypr/rotate_select.sh;
    executable = true;
  };

  # ───────── Waybar ─────────
  xdg.configFile."waybar/config.jsonc".source = ./dotfiles/waybar/config.jsonc;
  xdg.configFile."waybar/style.css".source    = ./dotfiles/waybar/style.css;
  xdg.configFile."waybar/cliphist.sh" = {
    source     = ./dotfiles/waybar/cliphist.sh;
    executable = true;
  };

  # ───────── Wofi ─────────
  xdg.configFile."wofi/config-app.ini".source  = ./dotfiles/wofi/config-app.ini;
  xdg.configFile."wofi/config-clip.ini".source = ./dotfiles/wofi/config-clip.ini;
  xdg.configFile."wofi/style.css".source       = ./dotfiles/wofi/style.css;

  # ───────── Local Scripts (~/.local/bin) ─────────
  home.file.".local/bin/waybar-refresh-label" = {
    source     = ./dotfiles/local-bin/waybar-refresh-label;
    executable = true;
  };
  home.file.".local/bin/waybar-refresh-toggle" = {
    source     = ./dotfiles/local-bin/waybar-refresh-toggle;
    executable = true;
  };
  home.file.".local/bin/waybar-power-monitor" = {
    source     = ./dotfiles/local-bin/waybar-power-monitor;
    executable = true;
  };
  home.file.".local/bin/waybar-memory-info" = {
    source     = ./dotfiles/local-bin/waybar-memory-info;
    executable = true;
  };

  # ───────────────────────────────────────────────────────────────
  # Phase 4: XDG & App Defaults
  # ───────────────────────────────────────────────────────────────

  # ───────── XDG User Directories ─────────
  xdg.userDirs = {
    enable      = true;
    desktop     = "${config.home.homeDirectory}/Desktop";
    download    = "${config.home.homeDirectory}/Downloads";
    templates   = "${config.home.homeDirectory}/Templates";
    publicShare = "${config.home.homeDirectory}/Public";
    documents   = "${config.home.homeDirectory}/Documents";
    music       = "${config.home.homeDirectory}/Music";
    pictures    = "${config.home.homeDirectory}/Pictures";
    videos      = "${config.home.homeDirectory}/Videos";
  };

  # ───────── Default Applications ─────────
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html"                     = "brave-browser.desktop";
      "x-scheme-handler/http"         = "brave-browser.desktop";
      "x-scheme-handler/https"        = "brave-browser.desktop";
      "x-scheme-handler/about"        = "brave-browser.desktop";
      "x-scheme-handler/unknown"      = "brave-browser.desktop";
      "x-scheme-handler/sgnl"         = "signal.desktop";
      "x-scheme-handler/signalcaptcha" = "signal.desktop";
      "text/plain"                    = "code.desktop";
      "application/pdf"               = "draw.desktop";
      "audio/vnd.wave"                = "deadbeef.desktop";
      "audio/flac"                    = "deadbeef.desktop";
      "audio/mp4"                     = "deadbeef.desktop";
      "audio/x-dsf"                   = "deadbeef.desktop";
      "image/jpeg"                    = "org.gnome.gThumb.desktop";
      "application/wps-office.docx"   = "wps-office-wps.desktop";
      "application/wps-office.xlsx"   = "calc.desktop";
      "application/wps-office.pptx"   = "impress.desktop";
    };
  };

  # ───────── Kanshi (Monitor Profiles) ─────────
  xdg.configFile."kanshi/config".source = ./dotfiles/kanshi/config;
}
