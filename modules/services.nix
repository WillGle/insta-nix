_: {
  # ───────── Core Services ─────────
  services = {
    dbus.enable = true;
    openssh = {
      enable = true;
      ports = [ 2222 ];
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
        AllowUsers = [ "will" ];
      };
    };
    flatpak.enable = true;
    upower.enable = true;
    udev.enable = true;
    acpid.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
    tailscale.enable = true;
  };

  security.polkit.enable = true;

}