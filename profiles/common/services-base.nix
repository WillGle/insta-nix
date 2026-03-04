{ pkgsUnstable, ... }:
{
  # Shared system services across hosts.
  services = {
    dbus.enable = true;
    flatpak.enable = true;
    upower.enable = true;
    udev.enable = true;
    acpid.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
    tailscale.enable = true;

    # AI / LLM
    ollama = {
      enable = true;
      package = pkgsUnstable.ollama;
      # Use Vulkan for the AMD GPU APU (ROCm crashes with exit status 2)
      acceleration = "vulkan";
    };
  };

  security.polkit.enable = true;
}
