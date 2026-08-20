{ lib, ... }: {
  networking = {
    hostName = "think14gryzen";

    firewall = {
      # "loose" required: ProtonVPN routes packets via proton0 but kernel routing
      # table points replies via the physical NIC — strict mode drops these.
      # mkForce because the tailscale module also sets this (to the same value)
      # once useRoutingFeatures is "client".
      checkReversePath = lib.mkForce "loose";
      trustedInterfaces = [
        "proton0"
      ];
    };
  };
}
