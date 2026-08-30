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
    sessionVariables = {
      TERMINAL = "foot";
    };

    file = {
      ".config/fastfetch/config.jsonc".source = ../../assets/common/fastfetch/config.jsonc;
    };
  };

  programs = {
    home-manager.enable = true;

    fish = {
      enable = true;
      shellInit = ''
        fish_add_path "$HOME/.cargo/bin"
      '';
      interactiveShellInit = ''
        set fish_greeting
        fastfetch --config ~/.config/fastfetch/config.jsonc
        echo "For fast terminal file check - Yazi"
      '';
      shellAliases = {
        ll = "eza -la --icons";
        gs = "git status";
        ".." = "cd ..";
        k = "kubectl";
        zed = "zeditor";
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
          font = "${osConfig.theme.fonts.mono.family}:size=${toString osConfig.theme.fonts.mono.size}";
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
        };
        # The default media rule calls `mpv` directly, which isn't installed, so
        # Enter did nothing on a video. Route through xdg-open instead to honour
        # the defaultApplications table below (video -> VLC, audio -> Tauon).
        open.prepend_rules = [
          {
            mime = "{audio,video}/*";
            use = [
              "open"
              "reveal"
            ];
          }
        ];
        # Defaults are image_bound = [ 5000 5000 ] / image_alloc = 512MiB, which
        # rejects any 40MP photo with "Image size exceeds limit". Both limits
        # apply to the magick previewer too (passed through as -limit).
        tasks = {
          image_alloc = 2147483648;
          image_bound = [
            40000
            40000
          ];
        };
        # The builtin image previewer is the Rust image crate, which has no RAW
        # decoder; route RAW to magick instead (built here with libraw). Matched
        # by name because RAW mime detection is unreliable - CR3 has no magic
        # entry, and NEF/ARW/DNG report as plain image/tiff.
        plugin =
          let
            raw = "*.{cr2,CR2,cr3,CR3,crw,CRW,nef,NEF,arw,ARW,dng,DNG,raf,RAF,orf,ORF,rw2,RW2,pef,PEF,srw,SRW,x3f,X3F}";
          in
          {
            prepend_preloaders = [
              {
                name = raw;
                run = "magick";
              }
            ];
            prepend_previewers = [
              {
                name = raw;
                run = "magick";
              }
            ];
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

    tmux = {
      enable = true;
      shortcut = "a"; # Changes prefix key from Ctrl-b to Ctrl-a
      baseIndex = 1; # Start window and pane numbering at 1 (instead of 0)
      mouse = true; # Enable mouse scrolling, clicking, and pane selection
      keyMode = "vi"; # Use Vi keybindings in copy mode
      escapeTime = 0; # Removes ESC key delay in Vim/Neovim

      terminal = "tmux-256color";

      # Popular Tmux plugins from nixpkgs
      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = catppuccin;
          extraConfig = ''
            set -g @catppuccin_flavor "mocha"
            set -g @catppuccin_status_background "default"
            set -g @catppuccin_window_status_style "rounded"
            set -g @catppuccin_window_number_position "left"
            set -g @catppuccin_window_flags "icon"
            set -g @catppuccin_window_text " #W"
            set -g @catppuccin_window_current_text " #W"
            set -g @catppuccin_date_time_icon " "
            set -g @catppuccin_date_time_text " %H:%M"
          '';
        }
        vim-tmux-navigator # Seamless Ctrl+h/j/k/l navigation between Vim & Tmux
        resurrect # Save/restore sessions across reboots (`Prefix + Ctrl-s` / `Prefix + Ctrl-r`)
        yank # Vi copy mode integration with system clipboard
      ];

      # Custom configuration extra lines
      extraConfig = ''
        # Enable 24-bit True Color support
        set -as terminal-features ",xterm-256color:RGB"
        set -ag terminal-overrides ",xterm-256color:RGB"

        # General UI settings
        set -g status-position bottom
        set -g status-justify absolute-centre
        set -g status-interval 5
        set -g renumber-windows on
        setw -g monitor-activity on
        set -g visual-activity off

        # Clean Minimalist Pane Borders
        set -g pane-border-style "fg=#313244"
        set -g pane-active-border-style "fg=#89b4fa"

        # Keybindings
        # Open new splits in current working directory
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
        unbind '"'
        unbind %

        # Reload configuration
        bind r source-file ~/.config/tmux/tmux.conf \; display-message "Tmux config reloaded!"

        # Session on the left, windows in the centre, context on the right
        set -g status-left-length 30
        set -g status-right-length 50
        set -g status-left "#{E:@catppuccin_status_session}"
        set -g status-right "#{E:@catppuccin_status_directory}"
        set -ag status-right "#{E:@catppuccin_status_date_time}"
      '';
    };

  };

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
        "x-scheme-handler/sgnl" = "signal.desktop";
        "x-scheme-handler/signalcaptcha" = "signal.desktop";
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
