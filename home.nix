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
      format = "[](#001f3f)\$username[](#001f3f)\$directory[](#004080)\$git_branch\$git_status[](black)\$python\$nodejs[](#ffffff)";

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
        symbol = "";
        style = "bold yellow";
        format = "[ $symbol $branch ]($style)";
      };
      git_status = {
        style = "green";
        format = "[$all_status]($style)";
      };
      python = {
        symbol = "";
        style = "yellow";
        format = "[ $symbol $version ]($style)";
      };
      nodejs = {
        symbol = "";
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
}
