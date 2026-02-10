{ config, lib, pkgs, ... }:

{
  # ───────── Virtualization ─────────
  virtualisation.docker.enable = true;

  # ───────── Core Services ─────────
  services.dbus.enable = true;
  services.openssh.enable = true;
  services.flatpak.enable = true;
  services.upower.enable = true;
  services.udev.enable = true;
  services.acpid.enable = true;
  security.polkit.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # ───────── Locale / Time ─────────
  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "vi_VN"; LC_IDENTIFICATION = "vi_VN"; LC_MEASUREMENT = "vi_VN";
    LC_MONETARY = "vi_VN"; LC_NAME = "vi_VN"; LC_NUMERIC = "vi_VN";
    LC_PAPER = "vi_VN"; LC_TELEPHONE = "vi_VN"; LC_TIME = "vi_VN";
  };
}
