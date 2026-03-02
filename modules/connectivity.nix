{
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
    firewall = {
      enable = true;
      allowedTCPPorts = [ 2222 ];
      # "loose" required: ProtonVPN routes packets via proton0 but kernel routing
      # table points replies via the physical NIC — strict mode drops these.
      checkReversePath = "loose";
      trustedInterfaces = [
        "proton0"
        "ipv6leakintrf0"
        "tailscale0"
      ];
    };
    # Disable resolvconf — systemd-resolved is the single source of truth.
    resolvconf.enable = false;
  };

  # ───────── DNS / Resolver ─────────
  # systemd-resolved acts as the stub resolver (127.0.0.53).
  # Priority order:
  #   1. VPN interface DNS (proton0: 10.2.0.1 with Domain=~.)  — when VPN is ON
  #   2. Per-link DNS from DHCP (pushed by NetworkManager)      — when VPN is OFF
  #   3. Fallback DNS below                                     — last resort
  services.resolved = {
    enable = true;
    # DNSSEC in allow-downgrade mode: validates when possible, downgrades gracefully.
    dnssec = "allow-downgrade";
    # Fallback DNS — last resort.
    fallbackDns = [ "1.1.1.1" "8.8.8.8" ];
    extraConfig = ''
      # Global DNS — ensures resolution even if link-specific DNS is rejected/invalid.
      DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
      # DNSOverTLS disabled: prevents browser DoH conflicts and VPN double-encryption.
      DNSOverTLS=no
      # Reduce network noise and potential hangs
      LLMNR=no
      MulticastDNS=no
    '';
  };

  # Use the stub resolver socket so all apps consistently use systemd-resolved.
  environment.etc."resolv.conf".source = "/run/systemd/resolve/stub-resolv.conf";
}

