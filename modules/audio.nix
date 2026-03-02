{ 
  # ───────── Audio ─────────
  security.rtkit.enable = true;
  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = false;
      wireplumber = {
        enable = true;
        extraConfig = {
          "10-policy" = {
            "wireplumber.settings" = {
              "device.restore-default-node" = true;
              "node.restore-default-node" = true;
            };
          };
          "11-bluetooth-policy" = {
            "wireplumber.settings" = {
              "bluetooth.autoswitch-to-headset-profile" = true;
            };
            "monitor.bluez.properties" = {
              "bluez5.enable-sbc-xq" = true;
              "bluez5.enable-msbc" = true;
              "bluez5.enable-hw-volume" = true;
              "bluez5.roles" = [
                "a2dp_sink"
                "a2dp_source"
                "headset_head_unit"
                "headset_audio_gateway"
              ];
            };
            "monitor.bluez.rules" = [
              {
                matches = [
                  {
                    "device.api" = "bluez5";
                  }
                ];
                actions = {
                  update-props = {
                    "priority.driver" = 5000;
                    "priority.session" = 5000;
                  };
                };
              }
            ];
          };
        };
      };
    };
  };
}
