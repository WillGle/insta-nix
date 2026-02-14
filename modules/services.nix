_: {
  # ───────── Core Services ─────────
  services = {
    dbus.enable = true;
    openssh.enable = true;
    flatpak.enable = true;
    upower.enable = true;
    udev.enable = true;
    acpid.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
  };

  security.polkit.enable = true;

}