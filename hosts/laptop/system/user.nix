{
  pkgs,
  lib,
  ...
}:
{
  # Threat model (intentional):
  # `will` is the primary owner-admin account for this personal machine,
  # so near-root capabilities are accepted for operational convenience.
  users.users.will = {
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
      "wireshark"
    ];
  };

  programs.fish.enable = true;

  # User-facing aliases belong to Home Manager. This removes NixOS's default
  # `ll` alias so it cannot compete with the Fish alias in modules/home/shell.nix.
  environment.shellAliases.ll = lib.mkForce null;
}
