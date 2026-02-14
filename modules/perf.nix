_: {
  # Nix caches and build parallelism.
  # Nix settings moved to core.nix

  # zram swap (tune memoryPercent).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50; # Tune 25-75 depending on RAM and swap behavior.
  };

  boot.kernel.sysctl = {
    # zram-friendly swapping (tune 10-30).
    "vm.swappiness" = 20;
  };

  # CPU policy.
  powerManagement.enable = true;

  # Power daemon (pick one).
  services.power-profiles-daemon.enable = true;

  # SSD trim.
  services.fstrim.enable = true;
}
