{ config, ... }:
{
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowUsers = [ config.primaryUser.username ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 2222 ];
}
