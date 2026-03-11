{ lib, config, ... }:
let
  hasThemeColors = config ? theme && config.theme ? colors;
in

{
  assertions = [
    {
      assertion = hasThemeColors;
      message = "profiles/common/core.nix requires theme.colors. Import profiles/common/default.nix (or profiles/common/theme.nix before core.nix).";
    }
  ];

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
  console = lib.mkIf hasThemeColors (
    let
      c = config.theme.colors;
    in
    {
      font = "Lat2-Terminus16";
      colors = [
        (lib.removePrefix "#" c.base)
        (lib.removePrefix "#" c.error)
        (lib.removePrefix "#" c.success)
        (lib.removePrefix "#" c.warning)
        (lib.removePrefix "#" c.accent)
        (lib.removePrefix "#" c.purple)
        (lib.removePrefix "#" c.cyan)
        "b1b8c0" # light grey
        "6e7681" # dark grey
        (lib.removePrefix "#" c.error)
        (lib.removePrefix "#" c.success)
        (lib.removePrefix "#" c.warning)
        (lib.removePrefix "#" c.accent)
        (lib.removePrefix "#" c.purple)
        (lib.removePrefix "#" c.cyan)
        (lib.removePrefix "#" c.text)
      ];
    }
  );

  # ───────── System State Version ─────────
  system.stateVersion = "25.11";
}
