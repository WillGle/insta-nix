{ config, lib, pkgs, ... }:
{
  # PipeWire (PulseAudio disabled)
  services.pulseaudio.enable = false;
  services.pipewire = {
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

  security.rtkit.enable = true;

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };
  services.blueman.enable = true;
}
