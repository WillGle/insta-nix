{
  description = "NixOS config (split modules)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
  in {
    nixosConfigurations.Laptop = lib.nixosSystem {
      inherit system;
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix

        # Split modules
        ./modules/desktop.nix
        ./modules/networking.nix
        ./modules/laptop-power.nix
        ./modules/gpu.nix
        ./modules/audio.nix
        ./modules/users.nix
        ./modules/packages.nix
        ./modules/gaming.nix
      ];
    };
  };
}
