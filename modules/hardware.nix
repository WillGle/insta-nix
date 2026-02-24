{ pkgs, ... }:

{
  # ───────── Vulkan/VA-API (GPU) ─────────
  services.xserver.videoDrivers = [ "amdgpu" ];

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

  # ───────── Filesystems ─────────
  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/GENERIC_VAULT_UUID";
    fsType = "ext4";
    options = [
      "defaults"
      "noatime"
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # ───────── Bootloader ─────────
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
    kernelPackages = pkgs.linuxPackages;
    extraModulePackages = [ pkgs.linuxPackages.ryzen-smu ];

    initrd.kernelModules = [ "amdgpu" ];
    blacklistedKernelModules = [ "lenovo_wmi_gamezone" ];
  };

  # ───────── Performance & Tuning ─────────
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

  # ───────── Virtualization ─────────
  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };
}
