_: {
  imports = [ ./bluetooth.nix ];

  hardware = {
    enableAllFirmware = true;
    logitech.wireless.enable = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
          # LE Audio requires the kernel ISO socket feature as well as D-Bus APIs.
          KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e";
        };
      };
    };
  };

}
