{ ... }:
{
  programs = {
    steam = {
      enable = true;
      # No VK_DRIVER_FILES override needed any more: the system Mesa is stable
      # 25.2.6 again, which is the RADV that CS2 actually runs on. The override
      # existed only to route around unstable Mesa 26.2 — see the note in
      # system/graphics.nix.
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
    };

    gamemode.enable = true;
  };
}
