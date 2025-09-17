{
  description = "Flake wrapper for existing NixOS config";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
  in {
    nixosConfigurations.Laptop = lib.nixosSystem {
      inherit system;
      modules = [
        # Use your current files directly — unchanged
        ./hardware-configuration.nix
        ./configuration.nix

        # (Optional) preload empty module stubs so you can start moving bits later
        # ./modules/desktop.nix
        # ./modules/gpu.nix
        # ./modules/audio.nix
        # ./modules/laptop-power.nix
        # ./modules/networking.nix
        # ./modules/users.nix
        # ./modules/gaming.nix
        # ./modules/packages.nix
      ];
    };
  };
}
