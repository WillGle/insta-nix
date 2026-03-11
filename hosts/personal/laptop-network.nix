_: {
  networking = {
    hostName = "Laptop";

    firewall = {
      # "loose" required: ProtonVPN routes packets via proton0 but kernel routing
      # table points replies via the physical NIC — strict mode drops these.
      checkReversePath = "loose";
      trustedInterfaces = [
        "proton0"
        "tailscale0"
      ];
    };
  };
}
