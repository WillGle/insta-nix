{ lib, config, ... }:

{
  # ───────── Nix Configuration ─────────
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Explicit cache and key for cache.nixos.org (Standardization)
    substituters = lib.mkAfter [
      "https://cache.nixos.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "cache.nixos.org-1:6NCHdD59X3yjrwW3CvkxuV2L0GyGq5qF5S727Z6IQkQ="
    ];

    # Store dedup and build parallelism
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    keep-outputs = true;
    keep-derivations = true;
  };

  # Nix garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;

  # ───────── Console ─────────
  console = {
    font = "Lat2-Terminus16";
    colors = with config.theme.colors; [
      (lib.removePrefix "#" base)
      (lib.removePrefix "#" error)
      (lib.removePrefix "#" success)
      (lib.removePrefix "#" warning)
      (lib.removePrefix "#" accent)
      (lib.removePrefix "#" purple)
      (lib.removePrefix "#" cyan)
      "b1b8c0" # light grey
      "6e7681" # dark grey
      (lib.removePrefix "#" error)
      (lib.removePrefix "#" success)
      (lib.removePrefix "#" warning)
      (lib.removePrefix "#" accent)
      (lib.removePrefix "#" purple)
      (lib.removePrefix "#" cyan)
      (lib.removePrefix "#" text)
    ];
  };

  # ───────── System State Version ─────────
  system.stateVersion = "25.11";
}
