{
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
{
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Prefer newer amdgpu firmware over stable copies on path collisions.
  hardware.firmware = lib.mkBefore [ pkgsUnstable.linux-firmware ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Keep system Mesa on stable: mixing unstable drivers with stable libdrm
    # broke Steam, CS2, VA-API, and Chromium acceleration.
    # Scope unstable RADV to llama.cpp with matching libdrm in system/llm.nix.
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
      # Keep libva and Mesa in the same package set to preserve the VA driver ABI.
      libva
      libva-utils
      libva-vdpau-driver
      mesa
      mesa.opencl
      # Keep the AMD OpenCL ICD for clinfo and other OpenCL consumers.
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
