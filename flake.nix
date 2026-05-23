{
  description = "NixOS config (multi-host, remote-migrate friendly)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
      };

      mkHomeModule = homeOverlay: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          users.will.imports = [
            ./modules/home/base.nix
            ./modules/home/desktop.nix
            homeOverlay
          ];
          extraSpecialArgs = {
            inherit inputs;
            inherit pkgsUnstable;
          };
        };
      };

      mkHost =
        {
          hostModule,
          sshModule,
          enableHome ? false,
          homeModule ? null,
        }:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit pkgsUnstable;
          };
          modules =
            [
              hostModule
              sshModule
            ]
            ++ lib.optionals enableHome [
              home-manager.nixosModules.home-manager
              (mkHomeModule homeModule)
            ];
        };
    in
    {
      nixosConfigurations = {
        think14gryzen = mkHost {
          hostModule = ./hosts/think14gryzen/default.nix;
          enableHome = true;
          homeModule = ./hosts/think14gryzen/home.nix;
          sshModule = ./modules/nixos/ssh/strict.nix;
        };

        plank = mkHost {
          hostModule = ./hosts/plank/default.nix;
          sshModule = ./modules/nixos/ssh/plank.nix;
        };
      };
    };
}
