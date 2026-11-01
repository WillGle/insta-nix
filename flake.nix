{
  description = "NixOS config (multi-host, remote-migrate friendly)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;

      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (import ./overlays/common.nix)
          (import ./overlays/unstable.nix)
        ];
      };

      mkHomeModule = homeOverlay: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          users.will.imports = [ homeOverlay ];
          extraSpecialArgs = {
            inherit inputs;
            inherit pkgsUnstable;
          };
        };
      };

      mkHost =
        {
          hostModule,
          homeModule ? null,
        }:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit pkgsUnstable;
          };
          modules = [
            hostModule
          ]
          ++ lib.optionals (homeModule != null) [
            home-manager.nixosModules.home-manager
            (mkHomeModule homeModule)
          ];
        };

      hostConfigs = {
        think14gryzen = mkHost {
          hostModule = ./hosts/think14gryzen/default.nix;
          homeModule = ./hosts/think14gryzen/home.nix;
        };

        plank = mkHost {
          hostModule = ./hosts/plank/default.nix;
        };
      };

    in
    {
      nixosConfigurations = hostConfigs;
    };
}
