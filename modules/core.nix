{
  lib,
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

  # ───────── System State Version ─────────
  system.stateVersion = "25.11";
}
