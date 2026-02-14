{ pkgs, ... }:
{
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

  # Shell / prompt delegated to Home Manager
  # programs.fish.enable = true;
  # programs.starship.enable = true;
  programs.fish.enable = true; # Keep system-wide fish enabling, but config in HM

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
