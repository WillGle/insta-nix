{
  lib,
  osConfig,
  pkgs,
  ...
}:

{
  programs = {
    foot = {
      enable = true;
      settings = {
        main = {
          term = "foot";
          font = "${osConfig.theme.fonts.mono.family}:size=${toString osConfig.theme.fonts.mono.size}";
          pad = "15x15";
        };

        colors-dark = {
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
      shellWrapperName = "yy";
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
        # Use MIME defaults via xdg-open; the default mpv command is unavailable.
        open.prepend_rules = [
          {
            mime = "{audio,video}/*";
            use = [
              "open"
              "reveal"
            ];
          }
        ];
        # Raise both limits for 40 MP previews; magick uses them too.
        tasks = {
          image_alloc = 2147483648;
          image_bound = [
            40000
            40000
          ];
        };
        # Use magick with libraw for RAW files. Match names because MIME
        # detection misses CR3 or reports TIFF for NEF, ARW, and DNG.
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

    tmux = {
      enable = true;
      shortcut = "a";
      baseIndex = 1;
      mouse = true;
      keyMode = "vi";
      escapeTime = 0;

      terminal = "tmux-256color";

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
        vim-tmux-navigator # Ctrl+h/j/k/l across Vim and Tmux
        resurrect # Save: Prefix + Ctrl-s; restore: Prefix + Ctrl-r
        yank # Copy to the system clipboard
      ];

      extraConfig = ''
        # Enable 24-bit True Color support
        set -as terminal-features ",foot*:RGB"

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
}
