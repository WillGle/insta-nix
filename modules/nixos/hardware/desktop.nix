_: {
  imports = [ ./bluetooth.nix ];

  # Shared hardware connectivity defaults
  hardware = {
    enableAllFirmware = true;
    logitech.wireless.enable = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
          FastConnectable = true;
        };
        Policy = {
          AutoEnable = true;
        };
      };
    };
  };

}
