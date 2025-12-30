{
  description = "NixOS config (split modules)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;

    pkgsUnstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [ "antigravity" ];
    };
  in {
    nixosConfigurations.Laptop = lib.nixosSystem {
      inherit system;
      modules = [
        ./hardware-configuration.nix
        ./modules/base.nix
        ./modules/perf.nix
        ./modules/desktop.nix
        ./modules/networking.nix
        ./modules/gpu.nix
        ./modules/audio.nix
        ./modules/users.nix

        ({ ... }: {
          environment.systemPackages = [
            pkgsUnstable.antigravity
            # nếu cần: pkgsUnstable.antigravity-fhs
          ];
        })

        ./modules/packages.nix
        ./modules/gaming.nix
        ./modules/fonts.nix
      ];
    };
  };
}
