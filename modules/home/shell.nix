{ ... }:

{
  home = {
    sessionVariables = {
      TERMINAL = "foot";
    };

    file = {
      ".config/fastfetch/config.jsonc".source = ../../assets/common/fastfetch/config.jsonc;
    };
  };

  programs = {
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
        palette = "proxmox";

        format = "[╭─](bold accent) $os$hostname$directory$nix_shell$git_branch$git_status$fill$python$nodejs$cmd_duration$status\n[╰─](bold accent) $character ";

        character = {
          success_symbol = "[❯](bold accent) ";
          error_symbol = "[❯](bold error) ";
        };

        os = {
          disabled = false;
          style = "bold accent";
          format = "[$symbol]($style) ";
          symbols.Debian = "";
          symbols.NixOS = "";
        };

        hostname = {
          ssh_only = false;
          style = "bold accent";
          format = "[$hostname]($style) ";
        };

        directory = {
          style = "bold cyan";
          format = "[  $path]($style) ";
          truncation_length = 5;
          truncation_symbol = "";
          truncate_to_repo = false;
        };

        git_branch = {
          symbol = "";
          style = "bold warning";
          format = "[›](dimmed text) [$symbol $branch]($style) ";
        };

        git_status = {
          format = "[$all_status$ahead_behind]($style) ";
          style = "text";
          conflicted = "[󰞇 conflict](bold error) ";
          ahead = "[󰁝 ahead](bold success) ";
          behind = "[󰁅 behind](bold warning) ";
          diverged = "[󰹹 diverged](bold error) ";
          untracked = "[ ?](bold warning) ";
          stashed = "[󰏗 stash](bold purple) ";
          modified = "[ !](bold warning) ";
          staged = "[ +](bold success) ";
          renamed = "[󰑕 »](bold cyan) ";
          deleted = "[󰆴 ✘](bold error) ";
        };

        fill = {
          symbol = "─";
          style = "dimmed mantle";
        };

        python = {
          symbol = "";
          style = "bold purple";
          format = "[ $symbol $version ]($style)";
        };

        nodejs = {
          symbol = "";
          style = "bold success";
          format = "[ $symbol $version ]($style)";
        };

        nix_shell = {
          style = "bold purple";
        };

        cmd_duration = {
          min_time = 1000;
          style = "bold cyan";
          format = "[ 󰅐 $duration ]($style)";
        };

        status = {
          disabled = false;
          format = "[ $symbol$status ]($style) ";
          style = "bold error";
          symbol = "✘ ";
        };

        palettes.proxmox = {
          accent = "#89b4fa";
          cyan = "#89dceb";
          warning = "#f9e2af";
          text = "#cdd6f4";
          error = "#f38ba8";
          success = "#a6e3a1";
          purple = "#cba6f7";
          mantle = "#181825";
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
      # Bash remains an external user-owned startup file. Do not add a second
      # hook if Bash or Zsh become Home Manager-managed later.
      enableBashIntegration = false;
      enableZshIntegration = false;
    };
  };
}
