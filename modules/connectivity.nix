_:

{
  # ───────── Audio ─────────
  security.rtkit.enable = true;
  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = false;
      wireplumber = {
        enable = true;
        extraConfig = {
          "10-policy" = {
            "wireplumber.settings" = {
              "device.restore-default-node" = true;
              "node.restore-default-node" = true;
            };
          };
        };
      };
    };
  };

  # ───────── Bluetooth Configuration ─────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };

  services.blueman.enable = true;

  # ───────── Networking ─────────
  networking = {
    hostName = "Laptop";
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [
        "proton0"
        "ipv6leakintrf0"
        "tailscale0"
      ];
    };
    # Strict DNS / VPN Leak Protection
    # Disabling resolvconf to let systemd-resolved handle DNS exclusively (prevents leaks).
    resolvconf.enable = false;
  };

  # ───────── DNS / Resolver ─────────
  services.resolved = {
    enable = true;
    dnssec = "false";
    fallbackDns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
    domains = [ "~." ];
  };

  environment.etc."resolv.conf".source = "/run/systemd/resolve/stub-resolv.conf";
}
