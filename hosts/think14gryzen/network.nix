{ lib, ... }: {
  networking = {
    hostName = "think14gryzen";

    firewall = {
      # ProtonVPN replies use the physical NIC; strict reverse-path filtering
      # drops them. Force loose mode to preserve asymmetric routing.
      checkReversePath = lib.mkForce "loose";
      trustedInterfaces = [
        "proton0"
      ];
    };
  };
}
