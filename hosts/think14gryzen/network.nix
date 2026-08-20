{ lib, ... }: {
  networking = {
    hostName = "think14gryzen";

    firewall = {
      # "loose" required: ProtonVPN routes packets via proton0 but kernel routing
      # table points replies via the physical NIC — strict mode drops these.
      # mkForce keeps this pinned regardless of what other modules want.
      checkReversePath = lib.mkForce "loose";
      trustedInterfaces = [
        "proton0"
      ];
    };
  };
}
