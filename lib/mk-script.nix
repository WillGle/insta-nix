{
  pkgs,
  lib,
  defaultDir,
}:
{
  name,
  dir ? defaultDir,
  runtimeInputs ? [ ],
  vars ? { },
  excludeShellChecks ? [ ],
}:
let
  source = dir + "/${name}";
  input = builtins.readFile source;
  keys = builtins.attrNames vars;
  rendered = builtins.replaceStrings (map (key: "@${key}@") keys) (map (
    key: toString vars.${key}
  ) keys) input;
  body =
    assert lib.assertMsg (lib.all (
      key: lib.hasInfix "@${key}@" input
    ) keys) "Unused replacement in ${name}";
    assert lib.assertMsg (
      keys == [ ] || !(lib.any builtins.isList (builtins.split "@[a-zA-Z_][0-9a-zA-Z_'-]*@" rendered))
    ) "Unsubstituted variable in ${name}";
    lib.concatStringsSep "\n" (lib.drop 1 (lib.splitString "\n" rendered));
in
pkgs.writeShellApplication {
  inherit name runtimeInputs excludeShellChecks;
  text = body;
}
