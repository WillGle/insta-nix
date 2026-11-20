{
  pkgs,
  lib,
  ...
}:
{
  # The machine owner accepts near-root group access for daily administration.
  users.users.will = {
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "seat"
      "audio"
      "dialout"
      "bluetooth"
      "docker"
      "render"
      "wireshark"
    ];
  };

  programs.fish.enable = true;

  # Home Manager owns ll; remove the competing NixOS default.
  environment.shellAliases.ll = lib.mkForce null;
}
