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

  # Ryzen laptop host policy and desktop integration.

  services = {
    xserver = {
      enable = true;

      xkb.layout = "us";

      excludePackages = with pkgs; [
        xterm
      ];

      desktopManager.xterm.enable = false;
    };

    # iOS USB multiplexing daemon
    usbmuxd.enable = true;

    # SSD trim.
    fstrim.enable = true;

    openlogi.enable = true;

    # scx_lavd was tried here (2026-08-22) and REMOVED: measured -21% prefill
    # and relative jittery decode (27.9-31.9 vs a stable 33.2 t/s) on llama.cpp
    # Vulkan — latency-first scheduling starves the GPU submission thread.
    # EEVDF default wins for this box's throughput-first priorities.

    udev.extraRules = ''
      # FiiO DAC (JadeAudio JA11 / SNOWSKY Melody) for WebHID access
      ATTRS{idVendor}=="2972", ATTRS{idProduct}=="0126", MODE="0666", GROUP="users"
    '';
  };

  systemd.services = {
    # Drop the ~5.4s boot blocker on the critical chain: docker is the only
    # consumer of network-online.target and brings up its own docker0 bridge,
    # so waiting for full connectivity before graphical.target buys nothing.
    NetworkManager-wait-online.enable = false;
  };

  # This laptop shares system RAM with the APU and local LLM workloads. Keep
  # Nix from running several full-core derivations at once, and bound the
  # RAM-backed temporary filesystem so builds cannot crowd out the session.
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
