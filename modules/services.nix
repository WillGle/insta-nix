{ pkgsUnstable, ... }: {
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

    # ───────── AI / LLM ─────────
    ollama = {
      enable = true;
      package = pkgsUnstable.ollama;
      # Use Vulkan for the AMD GPU APU (ROCm crashes with exit status 2)
      acceleration = "vulkan";
    };
  };

  security.polkit.enable = true;

}