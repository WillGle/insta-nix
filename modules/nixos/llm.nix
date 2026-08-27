{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  llamaCppVulkan = pkgsUnstable.llama-cpp.override { vulkanSupport = true; };

  # RADV from unstable Mesa 26.2, scoped to llama.cpp alone.
  #
  # Why bother: measured 2026-08-24, gemma-3-4b UD-Q4, kernel 7.2, performance
  # profile, same llama.cpp build — pp512 804 t/s on 26.2 vs 617 t/s on the
  # system's stable 25.2.6. A ~30% prefill win, which is what dominates
  # latency when pi reads a whole repo. Decode is bandwidth-bound (~85% of the
  # LPDDR5 ceiling) and barely moves: 31.0 vs 29.0 t/s. RADV 26.2 advertises
  # `fp16: dot2` where 25.2 reports plain `fp16: 1`; that extra matmul path is
  # where the prefill gain comes from.
  #
  # Why scoped and not system-wide: ba72b36 made it system-wide and broke
  # Steam, CS2, VA-API decode, and Chromium's GPU stack. Mesa's driver .so
  # files declare no libdrm dependency and borrow those symbols from whatever
  # process loads them; 26.2 needs libdrm 2.4.134 and every nixpkgs-25.11
  # program ships 2.4.129. See the note in hosts/think14gryzen/system.nix.
  #
  # THIS IS SAFE ONLY WHILE llamaCppVulkan COMES FROM pkgsUnstable — that is
  # what puts libdrm 2.4.134 in the process so RADV 26.2 can resolve against
  # it. If llama.cpp ever moves to stable pkgs, delete this wrapper in the
  # same commit or it will fail exactly the way Brave did.
  radvUnstableIcd = "${pkgsUnstable.mesa}/share/vulkan/icd.d/radeon_icd.x86_64.json";

  llamaCppWrapped = pkgs.symlinkJoin {
    name = "llama-cpp-radv-26.2";
    paths = [ llamaCppVulkan ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # VK_DRIVER_FILES replaces the ICD search path rather than extending it.
    # That is intentional here: this box has exactly one GPU, and pinning the
    # list keeps llama.cpp off the system's 25.2 RADV.
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

  # llmfit from unstable (not in 25.11), wrapped with the GTT ceiling: its
  # autodetect only sees the 4G VRAM carve and would hide most models.
  llmfitWrapped = pkgs.writeShellScriptBin "llmfit" ''
    exec ${pkgsUnstable.llmfit}/bin/llmfit --memory 22G "$@"
  '';

  llmPackages = [
    llamaCppWrapped
    llmfitWrapped
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
      name = "llm-list";
      dir = ../../hosts/think14gryzen/assets/local-bin;
      runtimeInputs = with pkgs; [
        coreutils
        curl
        findutils
        gawk
        jq
        python3Packages.gguf
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
