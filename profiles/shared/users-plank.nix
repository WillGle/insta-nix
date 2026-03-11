{ pkgs, ... }:
{
  users.users.will = {
    isNormalUser = true;
    description = "will";
    shell = pkgs.bashInteractive;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # SSH key is the primary auth gate for Plank; avoid password lockout after first boot.
  security.sudo.wheelNeedsPassword = false;
}
