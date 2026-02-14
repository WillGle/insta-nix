{
  config,
  lib,
  pkgs,
  ...
}:
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

  # Shell / prompt
  programs.fish.enable = true;
  programs.starship.enable = true;

  # sudo rule for tlp (only if tlp is enabled)
  # sudo rule for tlp (only if tlp is enabled)
  # sudo rule for tlp (only if tlp is enabled)
  security.sudo.extraRules =
    (lib.optionals config.services.tlp.enable [
      {
        users = [ "will" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/tlp";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ])
    ++ [
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
