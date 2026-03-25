{ ... }:
{
  imports = [
    ./laptop-hardware.nix
    ./laptop-storage.nix
    ./laptop-network.nix
    ../../profiles/shared/base.nix
    ../../profiles/shared/users-will.nix
    ../../profiles/personal/laptop-system.nix
    ../../profiles/shared/kubernetes.nix
    ../../profiles/shared/iac.nix
  ];
}
