{ pkgs, ... }:

{
  services = {
    xserver.videoDrivers = [ "amdgpu" ];

    # Power daemon (pick one).
    power-profiles-daemon.enable = true;

    # SSD trim.
    fstrim.enable = true;
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
