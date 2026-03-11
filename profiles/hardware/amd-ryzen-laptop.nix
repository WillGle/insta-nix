{ pkgs, ... }:

{
  services = {
    xserver.videoDrivers = [ "amdgpu" ];

    # Power daemon (pick one).
    power-profiles-daemon.enable = true;

    # SSD trim.
    fstrim.enable = true;
  };

  # Keep Lenovo battery reserve mode ON at boot.
  # Path discovery is dynamic inside toggle-battery-reserve.
  systemd.services.battery-reserve-default = {
    description = "Set Lenovo battery reserve mode to ON";
    wantedBy = [ "multi-user.target" ];
    wants = [ "systemd-udev-settle.service" ];
    after = [
      "systemd-modules-load.service"
      "systemd-udev-settle.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/toggle-battery-reserve on --wait 45";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
      libva
      libva-utils
      libva-vdpau-driver
      mesa
      rocmPackages.clr
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      libva
      libva-utils
      libva-vdpau-driver
    ];
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelParams = [ "amd_pstate=active" ];
    kernelModules = [
      "msr"
      "ryzen_smu"
    ];
    kernelPackages = pkgs.linuxPackages_6_12;
    extraModulePackages = [ pkgs.linuxPackages_6_12.ryzen-smu ];

    initrd.kernelModules = [ "amdgpu" ];
    blacklistedKernelModules = [ "lenovo_wmi_gamezone" ];
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 37; # Target ~10GB (37% of 27GB visible RAM)
    priority = 100;
  };

  boot.kernel.sysctl = {
    # zram-friendly swapping (tune 10-30).
    "vm.swappiness" = 20;
  };

  powerManagement.enable = true;

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };
}
