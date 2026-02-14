_: {
  # PipeWire (PulseAudio disabled)
  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = false;
      wireplumber.enable = true;
      wireplumber.extraConfig."10-policy" = {
        "wireplumber.settings" = {
          "device.restore-default-node" = true;
          "node.restore-default-node" = true;
        };
      };
    };
    blueman.enable = true;
  };
}
