{
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
{
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Newer amdgpu MES/SMU/VCN blobs than the 25.11 snapshot; mkBefore so the
  # unstable copy wins path collisions against the stable default set.
  hardware.firmware = lib.mkBefore [ pkgsUnstable.linux-firmware ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Mesa stays on stable (the nixpkgs-25.11 default) for the whole system.
    # ba72b36 moved it to unstable 26.2 for llama.cpp throughput; that broke
    # four separate things because Mesa's driver .so files declare NO libdrm
    # dependency — no RPATH, no DT_NEEDED — and resolve those symbols from
    # whichever process dlopens them. Mesa 26.2 wants libdrm 2.4.134 while
    # every nixpkgs-25.11 application ships 2.4.129, so serving 26.2
    # system-wide meant: Steam's i686 client dead on GLX, CS2 SIGSEGV in
    # RADV, VA-API decode dead (libva ABI), and Chromium/Brave silently
    # losing GPU acceleration entirely ("undefined symbol:
    # amdgpu_va_manager_query_sw_info" -> EGL init fails -> --use-gl=disabled).
    # The 26.2 throughput win is preserved where it is actually safe: scoped
    # to llama.cpp in modules/nixos/llm.nix, which is built from pkgsUnstable
    # and therefore already carries the matching libdrm.
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
      # libva must match the Mesa that provides the VA driver; both are stable
      # now, so these stay stable too. Mixing them is what killed hardware
      # video decode (stable libva 2.22 looks for __vaDriverInit_1_22, unstable
      # Mesa 26.2 exports only __vaDriverInit_1_24).
      libva
      libva-utils
      libva-vdpau-driver
      mesa
      mesa.opencl
      # AMD OpenCL ICD. Originally for DaVinci Resolve (removed 2026-08-22);
      # kept for clinfo and any OpenCL consumer.
      rocmPackages.clr
      rocmPackages.clr.icd
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      libva
      libva-utils
      libva-vdpau-driver
    ];
  };
}
