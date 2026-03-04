_: {
  services.openssh = {
    enable = true;
    ports = [
      22
      2222
    ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowUsers = [
        "will"
        "root"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [
    22
    2222
  ];
}
