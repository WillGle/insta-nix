{ pkgs, ... }:
{
  imports = [
    ./iac.nix
    ./kubernetes.nix
    ./docker.nix
  ];

  programs.wireshark.enable = true;

  environment.systemPackages = with pkgs; [
    nixd
    deadnix
    nixfmt
    statix
  ];
}
