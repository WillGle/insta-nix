{
  ...
}:

{
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
  # cpuFreqGovernor removed: redundant with amd_pstate=active

  # Power daemon (pick one).
  services.power-profiles-daemon.enable = true;

  # Optional: TLP for charge thresholds.
  # services.power-profiles-daemon.enable = false;
  # services.tlp = {
  #   enable = true;
  #   settings.STOP_CHARGE_THRESH_BAT0 = "80"; # Set to "0" for full charge.
  # };

  # SSD trim.
  services.fstrim.enable = true;

  # Optional: ccache for repeated C/C++ builds.
  # programs.ccache.enable = true;
}
