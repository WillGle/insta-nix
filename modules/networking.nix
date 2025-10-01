{ lib, pkgs, ... }:
{
  networking = {
    hostName = "Laptop";
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [ "proton0" "ipv6leakintrf0" ];
    };
    resolvconf.enable = false;
  };

  services.resolved = {
    enable = true;
    dnssec = "false";
    fallbackDns = [ "1.1.1.1" "8.8.8.8" ];
    domains = [ "~." ];
  };

  environment.etc."resolv.conf".source = "/run/systemd/resolve/stub-resolv.conf";
}
