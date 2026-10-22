{
  pkgsUnstable,
  ...
}:
{
  services = {
    power-profiles-daemon.enable = true;

    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
    # native-power-profile and power-profiles-daemon own AMD power policy.
    # cpupower-gui replayed a persisted 3.8 GHz cap after profile changes.
    cpupower-gui.enable = false;
  };

  boot = {
    kernelParams = [
      "amd_pstate=active"
      "transparent_hugepage=always"
      "ttm.pages_limit=5767168"
    ];
    kernelModules = [
      "msr"
      "ryzen_smu"
    ];
    # Use mainline for newer amdgpu and amd-pstate support; ryzen-smu builds
    # without the former LTS pin.
    kernelPackages = pkgsUnstable.linuxPackages_latest;
    extraModulePackages = [ pkgsUnstable.linuxPackages_latest.ryzen-smu ];

    initrd.kernelModules = [ "amdgpu" ];
    blacklistedKernelModules = [ "lenovo_wmi_gamezone" ];

    kernel.sysctl = {
      "vm.swappiness" = 20;
      # Disable readahead to avoid decompressing unused zram pages.
      "vm.page-cluster" = 0;
    };
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 37;
    priority = 100;
  };
}
