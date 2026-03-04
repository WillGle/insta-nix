{
  # Shared connectivity defaults.
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

  networking = {
    networkmanager = {
      enable = true;
      # Let systemd-resolved handle all DNS; NM will push per-interface DNS to resolved.
      dns = "systemd-resolved";
      # Ensure physical interfaces beat "leak protection" virtual routes (metric 95)
      settings = {
        connection = {
          "ipv4.route-metric" = 50;
          "ipv6.route-metric" = 50;
        };
      };
    };

    firewall.enable = true;

    # Disable resolvconf — systemd-resolved is the single source of truth.
    resolvconf.enable = false;
  };

  # DNS / Resolver
  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    fallbackDns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
    extraConfig = ''
      DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
      DNSOverTLS=no
      LLMNR=no
      MulticastDNS=no
    '';
  };

  environment.etc."resolv.conf".source = "/run/systemd/resolve/stub-resolv.conf";
}
