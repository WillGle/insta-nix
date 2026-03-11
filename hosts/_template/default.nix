{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ../../profiles/shared/base.nix
    ../../profiles/shared/users-will.nix
    # Add a personal system profile if needed, for example:
    # ../../profiles/personal/laptop-system.nix
  ];
}
