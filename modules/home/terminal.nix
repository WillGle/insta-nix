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
