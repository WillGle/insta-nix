{
  pkgs,
  lib,
  config,
  ...
}:

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
    colors = [
      "0d1117" "f85149" "3fb950" "d29922" "58a6ff" "bc8cff" "39c5cf" "b1b8c0"
      "6e7681" "ff7b72" "56d364" "e3b341" "79c0ff" "d2a8ff" "56d4dd" "f0f6fc"
    ];
  };

  # ───────── System State Version ─────────
  system.stateVersion = "25.11";
}
