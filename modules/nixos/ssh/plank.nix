{ lib, ... }:
let
  repoRoot = builtins.toString ../../..;
  localSeedKeyPath = "${repoRoot}/.local/remote-install/seed/etc/plank/authorized_keys";
  hasLocalSeedKey = builtins.pathExists localSeedKeyPath;
in
{
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowUsers = [ "will" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 2222 ];

  # Fallback key seed path copied into target root before nixos-install.
  system.activationScripts.plankAuthorizedKeySeed.text = ''
    if [ -f /etc/plank/authorized_keys ]; then
      install -d -m 700 -o will -g users /home/will/.ssh
      install -m 600 -o will -g users /etc/plank/authorized_keys /home/will/.ssh/authorized_keys
    fi
  '';

  warnings = lib.optionals (!hasLocalSeedKey) [
    ''
      plank: local seed key file not found at ${localSeedKeyPath}.
      Copy your key to /etc/plank/authorized_keys on target root before nixos-install,
      or paste a key manually during installer boot before install.
    ''
  ];
}
