{ ... }:
{
  powerManagement.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_BOOST_ON_AC = 1;
      CPU_MAX_PERF_ON_AC = "100";
      CPU_MIN_PERF_ON_AC = "20";

      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_BOOST_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = "35";
      CPU_MIN_PERF_ON_BAT = "5";

      PLATFORM_PROFILE_ON_AC  = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      STOP_CHARGE_THRESH_BAT0 = "1"; # ~80%
      # STOP_CHARGE_THRESH_BAT0 = "0"; # full
    };
  };

  # Giữ nguyên tham số kernel như bản gốc
  boot.kernelParams = [ "amd_pstate=active" ];
}
