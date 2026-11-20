{
  pkgs,
  lib,
  defaultDir,
}:
let
  mkScript = import ./mk-script.nix {
    inherit pkgs lib defaultDir;
  };
  scriptFile = pkg: {
    source = lib.getExe pkg;
    executable = true;
  };
in
{
  inherit mkScript scriptFile;
}
