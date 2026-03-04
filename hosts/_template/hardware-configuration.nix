{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Replace with host-generated values from nixos-generate-config.
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
