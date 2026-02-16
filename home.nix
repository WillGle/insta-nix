{
  config,
  pkgs,
  osConfig,
  ...
}:

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
      ".config/fastfetch/config.jsonc".source = ./dotfiles/fastfetch/config.jsonc;
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

        # Run fastfetch at shell startup with custom config
        fastfetch --config ~/.config/fastfetch/config.jsonc
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
        format = " $os[](${osConfig.theme.colors.accent})$username[](bg:${osConfig.theme.colors.mantle} fg:${osConfig.theme.colors.accent})$directory[](fg:${osConfig.theme.colors.mantle} bg:${osConfig.theme.colors.base})$git_branch$git_status[](fg:${osConfig.theme.colors.base} bg:${osConfig.theme.colors.mantle})$python$nodejs$memory_usage$battery[](fg:${osConfig.theme.colors.mantle}) ";

        os = {
          disabled = false;
          style = "bold white";
          symbols.NixOS = " ";
        };
        username = {
          style_user = "bold white bg:${osConfig.theme.colors.accent}";
          format = "[$user]($style)";
          show_always = true;
        };
        directory = {
          style = "bold white bg:${osConfig.theme.colors.mantle}";
          format = "[ $path ]($style)";
          truncation_length = 3;
          truncation_symbol = "…/";
        };
        git_branch = {
          symbol = "";
          style = "bold yellow bg:${osConfig.theme.colors.base}";
          format = "[ $symbol $branch ]($style)";
        };
        git_status = {
          style = "green bg:${osConfig.theme.colors.base}";
          format = "[$all_status]($style)";
        };
        python = {
          symbol = "";
          style = "yellow bg:${osConfig.theme.colors.mantle}";
          format = "[ $symbol $version ]($style)";
        };
        nodejs = {
          symbol = "";
          style = "green bg:${osConfig.theme.colors.mantle}";
          format = "[ $symbol $version ]($style)";
        };
        memory_usage = {
          disabled = false;
          threshold = 75;
          format = "[ 󰍛 $percentage ](bold purple bg:${osConfig.theme.colors.mantle})";
        };
        battery = {
          full_symbol = "󰁹 ";
          charging_symbol = "󰂄 ";
          discharging_symbol = "󰂃 ";
          display = [
            {
              threshold = 30;
              style = "bold red bg:${osConfig.theme.colors.mantle}";
            }
          ];
          format = "[ $symbol$percentage ](bold green bg:${osConfig.theme.colors.mantle})";
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

        "image/jpeg" = "org.gnome.gThumb.desktop";
        "application/wps-office.docx" = "wps-office-wps.desktop";
        "application/wps-office.xlsx" = "wps-office-et.desktop";
        "application/wps-office.pptx" = "wps-office-wpp.desktop";
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
      "waybar/style.css".text =
        let
          css = builtins.readFile ./dotfiles/waybar/style.css;
          c = osConfig.theme.colors;
        in
        builtins.replaceStrings
          [
            "{{base}}"
            "{{mantle}}"
            "{{text}}"
            "{{accent}}"
            "{{warning}}"
            "{{error}}"
            "{{purple}}"
          ]
          [
            c.base
            c.mantle
            c.text
            c.accent
            c.warning
            c.error
            c.purple
          ]
          css;
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

  # ───────── Systemd User Services ─────────
  systemd.user.services.pantheon-polkit-agent = {
    Unit = {
      Description = "Pantheon Polkit Agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.pantheon.pantheon-agent-polkit}/libexec/policykit-1-pantheon/io.elementary.desktop.agent-polkit";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
