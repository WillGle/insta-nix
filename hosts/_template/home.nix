{ ... }:
{
  imports = [
    ../../users/will/home.nix
    ../../modules/desktop/home.nix
    ../../modules/system/maintenance/home.nix
  ];

  # Host-specific Home Manager overrides live here. Shared desktop features
  # come from modules/desktop/home.nix; application assets stay beside their
  # owning module rather than under this host.
}
