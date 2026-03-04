{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:

{
  home = {
    username = "will";
    homeDirectory = "/home/will";
    stateVersion = "25.11";

    packages = with pkgs; [
      # Apps moved to system modules for stability.
    ];

    file = {
      ".config/fastfetch/config.jsonc".source = ../dotfiles/common/fastfetch/config.jsonc;
    };
  };

  programs = {
    home-manager.enable = true;

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting
        fastfetch --config ~/.config/fastfetch/config.jsonc
        echo "For fast terminal file check - Yazi"
      '';
      shellAliases = {
        ll = "eza -la --icons";
        gs = "git status";
        ".." = "cd ..";
      };
    };

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
          conflicted = "= ";
          ahead = "⇡ ";
          behind = "⇣ ";
          diverged = "⇕ ";
          untracked = "? ";
          stashed = "$ ";
          modified = "! ";
          staged = "+ ";
          renamed = "» ";
          deleted = "✘ ";
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

    foot = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=11";
          pad = "15x15";
        };
        colors = {
          alpha = 0.99;
          background = lib.removePrefix "#" osConfig.theme.colors.base;
          foreground = lib.removePrefix "#" osConfig.theme.colors.text;
          regular0 = lib.removePrefix "#" osConfig.theme.colors.mantle;
          regular1 = lib.removePrefix "#" osConfig.theme.colors.error;
          regular2 = lib.removePrefix "#" osConfig.theme.colors.success;
          regular3 = lib.removePrefix "#" osConfig.theme.colors.warning;
          regular4 = lib.removePrefix "#" osConfig.theme.colors.accent;
          regular5 = lib.removePrefix "#" osConfig.theme.colors.purple;
          regular6 = lib.removePrefix "#" osConfig.theme.colors.cyan;
          regular7 = lib.removePrefix "#" osConfig.theme.colors.text;
        };
      };
    };

    yazi = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        mgr = {
          show_hidden = true;
          sort_by = "mtime";
          sort_dir_first = true;
          linemode = "size";
        };
        preview = {
          max_width = 1000;
          max_height = 1000;
          preview_method = "sixel";
        };
      };
      theme = {
        flavor = {
          use = "default";
        };
        mgr = {
          border_symbol = "│";
          hovered = {
            fg = "black";
            bg = osConfig.theme.colors.accent;
          };
          preview_hovered = {
            underline = true;
          };
        };
      };
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    waybar = {
      enable = true;
      systemd.enable = false;
    };
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
        "x-scheme-handler/sgnl" = "signal.desktop";
        "x-scheme-handler/signalcaptcha" = "signal.desktop";
        "text/plain" = "code.desktop";
        "application/pdf" = "draw.desktop";

        "image/jpeg" = "org.gnome.gThumb.desktop";
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
      };
    };
  };
}
