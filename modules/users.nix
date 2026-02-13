{ config, lib, pkgs, ... }:
{
  users.users.will = {
    isNormalUser = true;
    description = "will";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager" "wheel" "video" "input"
      "seat" "audio" "bluetooth" "docker"
    ];
  };

  # Shell / prompt
  programs.fish.enable = true;
  programs.starship.enable = true;

  # sudo rule for tlp (only if tlp is enabled)
  security.sudo.extraRules = lib.mkIf config.services.tlp.enable [{
    users = [ "will" ];
    commands = [{
      command = "/run/current-system/sw/bin/tlp";
      options = [ "NOPASSWD" ];
    }];
  }];
}
