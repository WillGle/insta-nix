{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  llamaCppVulkan = pkgsUnstable.llama-cpp.override { vulkanSupport = true; };

  mkSystemScript =
    {
      name,
      dir ? ../../hosts/think14gryzen/assets/system-bin,
      runtimeInputs ? [ ],
      vars ? { },
      excludeShellChecks ? [ ],
    }:
    let
      source = dir + "/${name}";
      rendered = if vars == { } then source else pkgs.replaceVars source vars;
      body = lib.concatStringsSep "\n" (lib.drop 1 (lib.splitString "\n" (builtins.readFile rendered)));
    in
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      text = body;
    };

  llmLib = ../../hosts/think14gryzen/assets/llm/lib/common.sh;

  llmPackages = [
    llamaCppVulkan
    (mkSystemScript {
      name = "llm-pull";
      dir = ../../hosts/think14gryzen/assets/local-bin;
      runtimeInputs = with pkgs; [
        coreutils
        curl
        gnugrep
        gnused
        jq
      ];
    })
    (mkSystemScript {
      name = "llm-fit";
      dir = ../../hosts/think14gryzen/assets/local-bin;
      vars = { llmLib = "${llmLib}"; };
      excludeShellChecks = [ "SC2034" ];
      runtimeInputs = with pkgs; [
        coreutils
        gawk
      ];
    })
    (mkSystemScript {
      name = "llm-run";
      dir = ../../hosts/think14gryzen/assets/local-bin;
      vars = { llmLib = "${llmLib}"; };
      excludeShellChecks = [ "SC2034" ];
      runtimeInputs = with pkgs; [ coreutils ];
    })
  ];
in
{
  environment.systemPackages = llmPackages;
}
