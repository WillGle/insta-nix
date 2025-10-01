{
  description = "Flake wrapper for existing NixOS config (+ HM + devShell)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Home-Manager (sẽ bật ở bước 2)
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    pkgs = import nixpkgs { inherit system; };
  in {
    nixosConfigurations.Laptop = lib.nixosSystem {
      inherit system;
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix

        # Các module tách nhỏ
        ./modules/desktop.nix
        ./modules/networking.nix
        ./modules/laptop-power.nix
        ./modules/gpu.nix
        ./modules/audio.nix
        ./modules/users.nix
        ./modules/packages.nix
        ./modules/gaming.nix

        # Home-Manager sẽ thêm ở bước 2 (module hm.nix)
      ];
    };

    # DevShell cho ML
    devShells.${system} = {
      ml = pkgs.mkShell {
        name = "ml";
        packages = with pkgs; [
          python312
          (python312.withPackages (ps: with ps; [
            pip numpy pandas jupyterlab scikit-learn matplotlib
          ]))
          git
        ];
      };
    };
  };
}
