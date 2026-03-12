{
  description = "NixOS config (multi-host, remote-migrate friendly)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-rocm.url = "github:NixOS/nixpkgs/71caefce12ba78d84fe618cf61644dce01cf3a96";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-rocm,
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

      pkgsRocm = import nixpkgs-rocm {
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
          sshModule,
          enableHome ? false,
          homeOverlay ? null,
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
              (mkHomeModule homeOverlay)
            ];
        };
    in
    {
      packages.${system} = {
        # Pinned ROCm Python environment for Phase 4 canary checks.
        rocm-phase4-python = pkgsRocm.python311.withPackages (ps: [ ps.torchWithRocm ]);
      };

      nixosConfigurations = {
        Laptop = mkHost {
          hostModule = ./hosts/personal/laptop.nix;
          enableHome = true;
          homeOverlay = ./hosts/personal/laptop-home.nix;
          sshModule = ./profiles/shared/ssh-strict.nix;
        };

        generic-installer = mkHost {
          hostModule = ./hosts/generic/plank.nix;
          sshModule = ./profiles/shared/ssh-plank.nix;
        };
      };
    };
}
