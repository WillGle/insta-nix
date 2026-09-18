{
  pkgsUnstable,
  ...
}:
let
  # ryzen-smu upstream still calls cpuid_eax()/cpuid_ebx() bare; kernel >= 7.x
  # moved those helpers out of the headers smu.c pulls in transitively.
  ryzenSmuFixed = pkgsUnstable.linuxPackages_latest.ryzen-smu.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i '1i #include <asm/cpuid/api.h>' smu.c
    '';
  });
in
{
  services = {
    # Power daemon (pick one).
    power-profiles-daemon.enable = true;

    # Suspend on lid close when running on battery; keep awake on AC or when docked.
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
    # AMD power policy is managed only by native-power-profile and
    # power-profiles-daemon. cpupower-gui is intentionally disabled because
    # its persisted settings replayed a 3.8 GHz cap after profile changes.
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
    # Mainline from unstable (7.2 as of 2026-08): ~1.5y of amdgpu, amd-pstate
    # (per-core EPP boost), and sched_ext maturity over the old 6.12 LTS pin.
    # The pin existed for ryzen-smu, which builds against 7.2 since 2026-04.
    kernelPackages = pkgsUnstable.linuxPackages_latest;
    extraModulePackages = [ ryzenSmuFixed ];

    initrd.kernelModules = [ "amdgpu" ];
    blacklistedKernelModules = [ "lenovo_wmi_gamezone" ];

    kernel.sysctl = {
      # zram-friendly swapping (tune 10-30).
      "vm.swappiness" = 20;
      # zram is per-page CPU-decompressed: disable swap readahead so one fault
      # doesn't decompress 8 pages to serve 1. Recommended for compressed RAM swap.
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
