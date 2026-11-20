{ ... }:
{
  imports = [
    ../../users/will/home.nix
    ../../modules/system/maintenance/home.nix
    # Enable together with ../../modules/desktop/default.nix in default.nix:
    # ../../modules/desktop/home.nix
  ];

  # Host-specific Home Manager overrides live here. Application assets stay
  # beside their owning module rather than under this host.
}
