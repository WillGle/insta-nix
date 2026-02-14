{ config, pkgs, ... }:

{
  home = {
    username = "will";
    homeDirectory = "/home/will";
    stateVersion = "25.11";

    packages = with pkgs; [
      # Apps moved back to packages.nix for system stability
    ];

    # ───────── Local Scripts (~/.local/bin) ─────────
    file = {
      ".local/bin/waybar-refresh-label" = {
        source = ./dotfiles/local-bin/waybar-refresh-label;
        executable = true;
      };
      ".local/bin/waybar-refresh-toggle" = {
        source = ./dotfiles/local-bin/waybar-refresh-toggle;
        executable = true;
      };
      ".local/bin/waybar-power-monitor" = {
        source = ./dotfiles/local-bin/waybar-power-monitor;
        executable = true;
      };
      ".local/bin/waybar-memory-info" = {
        source = ./dotfiles/local-bin/waybar-memory-info;
        executable = true;
      };
    };
  };

  programs = {
    # Let Home Manager manage itself
    home-manager.enable = true;

    # ───────── Fish Shell ─────────
    fish = {
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
    starship = {
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
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  # ───────────────────────────────────────────────────────────────
  # Phase 3 & 4: Desktop Environment & XDG
  # ───────────────────────────────────────────────────────────────

  xdg = {
    enable = true;

    # ───────── XDG User Directories ─────────
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

    # ───────── Default Applications ─────────
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
        "x-scheme-handler/about" = "brave-browser.desktop";
        "x-scheme-handler/unknown" = "brave-browser.desktop";
        "x-scheme-handler/sgnl" = "signal.desktop";
        "x-scheme-handler/signalcaptcha" = "signal.desktop";
        "text/plain" = "code.desktop";
        "application/pdf" = "draw.desktop";
        "audio/vnd.wave" = "deadbeef.desktop";
        "audio/flac" = "deadbeef.desktop";
        "audio/mp4" = "deadbeef.desktop";
        "audio/x-dsf" = "deadbeef.desktop";
        "image/jpeg" = "org.gnome.gThumb.desktop";
        "application/wps-office.docx" = "wps-office-wps.desktop";
        "application/wps-office.xlsx" = "calc.desktop";
        "application/wps-office.pptx" = "impress.desktop";
      };
    };

    # ───────── Config Files ─────────
    configFile = {
      # Hyprland
      "hypr/hyprland.conf".source = ./dotfiles/hypr/hyprland.conf;
      "hypr/hyprpaper.conf".source = ./dotfiles/hypr/hyprpaper.conf;
      "hypr/hyprlock.conf".source = ./dotfiles/hypr/hyprlock.conf;
      "hypr/hypridle.conf".source = ./dotfiles/hypr/hypridle.conf;
      "hypr/autostart.conf" = {
        source = ./dotfiles/hypr/autostart.conf;
        executable = true;
      };
      "hypr/toggle_waybar.sh" = {
        source = ./dotfiles/hypr/toggle_waybar.sh;
        executable = true;
      };
      "hypr/rotate_select.sh" = {
        source = ./dotfiles/hypr/rotate_select.sh;
        executable = true;
      };

      # Waybar
      "waybar/config.jsonc".source = ./dotfiles/waybar/config.jsonc;
      "waybar/style.css".source = ./dotfiles/waybar/style.css;
      "waybar/cliphist.sh" = {
        source = ./dotfiles/waybar/cliphist.sh;
        executable = true;
      };

      # Wofi
      "wofi/config-app.ini".source = ./dotfiles/wofi/config-app.ini;
      "wofi/config-clip.ini".source = ./dotfiles/wofi/config-clip.ini;
      "wofi/style.css".source = ./dotfiles/wofi/style.css;

      # Kanshi
      "kanshi/config".source = ./dotfiles/kanshi/config;
    };
  };
}
