{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./system/user.nix
    ./system/graphics.nix
    ./system/power.nix
    ./system/gaming.nix
    ./system/packages.nix
  ];


  # Keep the personal image out of the flake/store and readable before login.
  # Seed once: desktop wallpaper changes must not replace the login wallpaper.
  system.activationScripts.sddmWallpaper.text = ''
    if [ ! -e /var/lib/sddm-wallpaper/background.jpg ]; then
      install -d -m 0755 /var/lib/sddm-wallpaper
      install -m 0644 \
        /home/will/.local/state/theme/wallpapers/4f3784341b72235528f6b54bf3355c0165122ff86f008f82bead99586b0f2f9e.jpg \
        /var/lib/sddm-wallpaper/background.jpg
    fi
  '';

  services = {
    tailscale.enable = true;
    xserver = {
      enable = true;

      xkb.layout = "us";

      excludePackages = with pkgs; [
        xterm
      ];

      desktopManager.xterm.enable = false;
    };

    usbmuxd.enable = true;

    fstrim.enable = true;

    openlogi.enable = true;

    # Keep EEVDF: scx_lavd reduced llama.cpp Vulkan prefill by 21%
    # and made decode less consistent.

    udev.extraRules = ''
      # FiiO DAC (JadeAudio JA11 / SNOWSKY Melody) for WebHID access
      ATTRS{idVendor}=="2972", ATTRS{idProduct}=="0126", MODE="0666", GROUP="users"
    '';
  };

  systemd.services = {
    # Docker is the only network-online consumer and creates its own bridge;
    # avoid delaying graphical startup for connectivity.
    NetworkManager-wait-online.enable = false;
  };

  # Limit parallel builds and tmpfs use to leave RAM for the APU and LLMs.
  nix.settings.max-jobs = lib.mkForce 1;
  boot.tmp.tmpfsSize = lib.mkForce "25%";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
    storageDriver = "overlay2";
  };

  security.rtkit.enable = true;

  programs.hyprland.enable = true;
}
