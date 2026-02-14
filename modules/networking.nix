_: {
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
