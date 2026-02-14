{
  description = "NixOS config (split modules)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-24-11.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-24-11,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;

      # Import specialized package sets
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "antigravity" ];
      };

      pkgs24_11 = import nixpkgs-24-11 {
        inherit system;
        config.allowUnfree = true;
      };

    in
    {
      nixosConfigurations.Laptop = lib.nixosSystem {
        inherit system;

        # Pass specialized package sets and inputs to all modules
        specialArgs = {
          inherit inputs;
          inherit pkgsUnstable pkgs24_11;
        };

        modules = [
          # Hardware & Core
          ./hardware-configuration.nix
          ./modules/core.nix
          ./modules/i18n.nix

          # System Modules
          ./modules/boot.nix
          ./modules/services.nix
          ./modules/perf.nix
          ./modules/desktop.nix
          ./modules/networking.nix
          ./modules/gpu.nix
          ./modules/audio.nix
          ./modules/users.nix
          ./modules/packages.nix
          ./modules/gaming.nix
          ./modules/fonts.nix

          # Home Manager
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              users.will = import ./home.nix;
              extraSpecialArgs = {
                inherit inputs;
                inherit pkgsUnstable pkgs24_11;
              };
            };
          }
        ];
      };
    };
}
