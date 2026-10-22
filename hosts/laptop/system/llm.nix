{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  llamaCppVulkan = pkgsUnstable.llama-cpp.override { vulkanSupport = true; };

  # Keep unstable RADV scoped to llama.cpp (see graphics.nix).
  # Use the same package set for llama.cpp and RADV to avoid mixed runtime ABIs;
  # reassess this wrapper when changing either package. Performance is unverified.
  radvUnstableIcd = "${pkgsUnstable.mesa}/share/vulkan/icd.d/radeon_icd.x86_64.json";

  llamaCppWrapped = pkgs.symlinkJoin {
    name = "llama-cpp-radv-26.2";
    paths = [ llamaCppVulkan ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # Replace the ICD search path to exclude stable RADV on this single-GPU host.
    postBuild = ''
      for bin in "$out"/bin/*; do
        [ -f "$bin" ] || continue
        wrapProgram "$bin" --set VK_DRIVER_FILES "${radvUnstableIcd}"
      done
    '';
  };

  mkSystemScript =
    {
      name,
      dir ? ../assets/system-bin,
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

  llmLib = ../assets/llm/lib/common.sh;

  # Override detection: llmfit sees only 4 GiB VRAM and misses shared GTT.
  llmfitWrapped = pkgs.writeShellScriptBin "llmfit" ''
    exec ${pkgsUnstable.llmfit}/bin/llmfit --memory 22G "$@"
  '';

  llmPackages = [
    llamaCppWrapped
    llmfitWrapped
    (mkSystemScript {
      name = "llm-pull";
      dir = ../assets/local-bin;
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
      dir = ../assets/local-bin;
      vars = {
        llmLib = "${llmLib}";
      };
      excludeShellChecks = [ "SC2034" ];
      runtimeInputs = with pkgs; [
        coreutils
        gawk
      ];
    })
    (mkSystemScript {
      name = "llm-list";
      dir = ../assets/local-bin;
      runtimeInputs = with pkgs; [
        coreutils
        curl
        findutils
        gawk
        jq
        python3Packages.gguf
      ];
    })
  ];
in
{
  environment.systemPackages = llmPackages;
}
