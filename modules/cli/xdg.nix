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
      setSessionVariables = true;
      desktop = "${config.home.homeDirectory}/Desktop";
      download = "${config.home.homeDirectory}/Downloads";
      templates = "${config.home.homeDirectory}/Templates";
      publicShare = "${config.home.homeDirectory}/Public";
      documents = "${config.home.homeDirectory}/Documents";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
    };

    # MIME defaults live in the system layer
    # (modules/desktop/mime.nix). The user-level
    # ~/.config/mimeapps.list is intentionally mutable so desktop
    # "Set as default" actions work without a NixOS rebuild.
  };
}
