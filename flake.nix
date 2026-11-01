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
      pkgs = nixpkgs.legacyPackages.${system};

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

      checks = {
        formatting =
          pkgs.runCommand "check-nixfmt"
            {
              nativeBuildInputs = [
                pkgs.findutils
                pkgs.nixfmt
              ];
            }
            ''
              find ${./.} -type f -name '*.nix' -print0 | xargs -0 nixfmt --check
              touch $out
            '';

        statix =
          pkgs.runCommand "check-statix"
            {
              nativeBuildInputs = [ pkgs.statix ];
            }
            ''
              statix check ${./.}
              touch $out
            '';

        deadnix =
          pkgs.runCommand "check-deadnix"
            {
              nativeBuildInputs = [ pkgs.deadnix ];
            }
            ''
              deadnix --fail ${./.}
              touch $out
            '';

        shellcheck =
          pkgs.runCommand "check-shellcheck"
            {
              nativeBuildInputs = [ pkgs.shellcheck ];
              homeCleanup =
                hostConfigs.think14gryzen.config.home-manager.users.will.home.file.".local/bin/home-cleanup".source;
            }
            ''
              # SC2034 is used for environment-style configuration in the bench
              # scripts; SC2209 is a style warning in existing benchmark code.
              shellcheck -x -s bash -S warning -e SC1091,SC2034,SC2209 \
                ${./scripts}/bench/*.sh \
                ${./theme}/scripts/lib/*.sh \
                ${./hosts}/think14gryzen/assets/hypr/*.sh \
                "$homeCleanup"
              touch $out
            '';

      };
    in
    {
      formatter.x86_64-linux = pkgs.nixfmt;

      checks.x86_64-linux = checks;

      nixosConfigurations = hostConfigs;
    };
}
