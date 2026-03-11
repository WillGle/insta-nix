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
            ./home/base.nix
            ./home/desktop-common.nix
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
          homeOverlay,
          sshModule,
          extraModules ? [ ],
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
              home-manager.nixosModules.home-manager
              (mkHomeModule homeOverlay)
            ]
            ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        Laptop = mkHost {
          hostModule = ./hosts/ryzen14/default.nix;
          homeOverlay = ./hosts/ryzen14/home-overlay.nix;
          sshModule = ./profiles/common/ssh-strict.nix;
        };

        "Laptop-bootstrap" = mkHost {
          hostModule = ./hosts/ryzen14/default.nix;
          homeOverlay = ./hosts/ryzen14/home-overlay.nix;
          sshModule = ./profiles/common/ssh-bootstrap.nix;
        };

        "Laptop-dns-canary" = mkHost {
          hostModule = ./hosts/ryzen14/default.nix;
          homeOverlay = ./hosts/ryzen14/home-overlay.nix;
          sshModule = ./profiles/common/ssh-strict.nix;
          extraModules = [ ./profiles/common/connectivity-dns-canary.nix ];
        };
      };
    };
}
