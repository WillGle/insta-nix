{
  description = "NixOS config (split modules)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-24-11.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-24-11, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;

    pkgsUnstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [ "antigravity" ];
    };

    pkgs24_11 = import nixpkgs-24-11 {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations.Laptop = lib.nixosSystem {
      inherit system;
      modules = [
        ./hardware-configuration.nix
        ./modules/boot.nix
        ./modules/services.nix
        ./modules/perf.nix
        ./modules/desktop.nix
        ./modules/networking.nix
        ./modules/gpu.nix
        ./modules/audio.nix
        ./modules/users.nix

        ({ ... }: {
          nixpkgs.config.allowUnfree = true;
          system.stateVersion = "25.05";
          environment.systemPackages = [
            pkgsUnstable.antigravity
            pkgs24_11.deadbeef
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
