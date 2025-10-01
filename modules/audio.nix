{ ... }:
{
  # PipeWire (tắt PulseAudio)
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = false;
  };

  # ĐÚNG: dùng security.rtkit (không phải services.rtkit)
  security.rtkit.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
}
