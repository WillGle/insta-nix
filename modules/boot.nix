{ config, lib, pkgs, ... }:

{
  # ───────── Filesystems ─────────
  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/GENERIC_VAULT_UUID";
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };

  # ───────── Bootloader ─────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "amd_pstate=active" ];
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # ───────── Early KMS ─────────
  boot.initrd.kernelModules = [ "amdgpu" ];
}
