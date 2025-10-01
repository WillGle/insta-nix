{ pkgs, ... }:
{
  users.users.will = {
    isNormalUser = true;
    description = "will";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager" "wheel" "video" "input"
      "seat" "audio" "bluetooth" "docker"
    ];
    packages = with pkgs; [ ];
  };

  # Shell / prompt
  programs.fish.enable = true;
  programs.starship.enable = true;

  # sudo rule for tlp
  security.sudo.extraRules = [{
    users = [ "will" ];
    commands = [{
      command = "/run/current-system/sw/bin/tlp";
      options = [ "NOPASSWD" ];
    }];
  }];
}
