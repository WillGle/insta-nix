{
  description = "NixOS config (multi-host, remote-migrate friendly)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rofi-hub = {
      url = "github:WillGle/rofi-hub";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      rofi-hub,
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
        laptop = mkHost {
          hostModule = ./hosts/laptop/default.nix;
          homeModule = ./users/will/home.nix;
        };

        minimal = mkHost {
          hostModule = ./hosts/minimal/default.nix;
        };
      };

      homeCleanupBin =
        hostConfigs.laptop.config.home-manager.users.will.home.file.".local/bin/home-cleanup".source;

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
              nativeBuildInputs = [
                pkgs.coreutils
                pkgs.findutils
                pkgs.gnugrep
                pkgs.shellcheck
              ];
              homeCleanup = homeCleanupBin;
            }
            ''
              # SC2034 is used for environment-style configuration in the bench
              # scripts; SC2209 is a style warning in existing benchmark code.
              # SC1090/SC1091 cover store-path sources injected by Nix.
              : > scripts.nul
              while IFS= read -r -d "" file; do
                if head -n 1 "$file" | grep -qE '^#!.*(bash|/sh)'; then
                  printf '%s\0' "$file" >> scripts.nul
                fi
              done < <(
                {
                  find ${./.}/modules -type f \( -path '*/assets/*' -o -path '*/lib/*' \) -print0
                  find ${./.}/scripts/bench -type f -name '*.sh' -print0
                }
              )
              xargs -0 shellcheck -x -s bash -S warning -e SC1090,SC1091,SC2034,SC2209 < scripts.nul
              shellcheck -x -s bash -S warning -e SC1090,SC1091,SC2034,SC2209 \
                ${./install.sh} \
                "$homeCleanup"
              touch $out
            '';

        shell-tests =
          pkgs.runCommand "check-shell-tests"
            {
              nativeBuildInputs = with pkgs; [
                bats
                coreutils
                findutils
                gawk
                gnused
                jq
                util-linux
              ];
              REPO_ROOT = "${./.}";
              HOME_CLEANUP_BIN = "${homeCleanupBin}";
            }
            ''
              export HOME=$(mktemp -d)
              bats ${./tests/shell}
              touch $out
            '';
      };
    in
    {
      formatter.x86_64-linux = pkgs.nixfmt;

      packages.x86_64-linux.nixos-install-tools = pkgs.nixos-install-tools;

      checks.x86_64-linux = checks;

      nixosConfigurations = hostConfigs;
    };
}
