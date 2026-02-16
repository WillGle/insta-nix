{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Shell enabled system-wide (Required for login shell)
  programs.fish.enable = true;

  users.users.will = {
    isNormalUser = true;
    description = "will";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "seat"
      "audio"
      "bluetooth"
      "docker"
      "render"
    ];
  };

  # sudo rule for tlp (only if tlp is enabled)
  security.sudo.extraRules = [
    {
      users = [ "will" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/ryzenadj";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
