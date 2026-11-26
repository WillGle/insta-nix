{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./packages.nix
    ../../base/default.nix
    ../../modules/system/maintenance
    ../../modules/system/hardware
    ../../modules/system/hardware/graphics-amd.nix
    ../../modules/system/llm
    ../../modules/system/power
    ../../modules/system/gaming.nix
    ../../modules/desktop/default.nix
    ../../modules/system/ssh
    ../../users/will/default.nix
    ../../modules/system/development
    inputs.rofi-hub.nixosModules.default
  ];

  primaryUser.username = "will";

  services.rofi-hub.enable = true;

  networking = {
    hostName = "laptop";

    firewall = {
      # ProtonVPN replies use the physical NIC; strict reverse-path filtering
      # drops them. Force loose mode to preserve asymmetric routing.
      checkReversePath = lib.mkForce "loose";
      trustedInterfaces = [
        "proton0"
      ];
    };
  };

  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/GENERIC_VAULT_UUID";
    fsType = "ext4";
    options = [
      "defaults"
      "noatime"
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # Keep the personal image out of the flake/store and readable before login.
  # Seed once: desktop wallpaper changes must not replace the login wallpaper.
  system.activationScripts.sddmWallpaper.text = ''
    if [ ! -e /var/lib/sddm-wallpaper/background.jpg ] &&
      [ -r /home/${config.primaryUser.username}/.local/share/sddm-wallpaper/background.jpg ]; then
      install -d -m 0755 /var/lib/sddm-wallpaper
      install -m 0644 \
        /home/${config.primaryUser.username}/.local/share/sddm-wallpaper/background.jpg \
        /var/lib/sddm-wallpaper/background.jpg
    fi
  '';

  # The machine owner accepts near-root group access for daily administration.
  users.users.${config.primaryUser.username} = {
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "seat"
      "audio"
      "dialout"
      "bluetooth"
      "docker"
      "render"
      "wireshark"
    ];
  };

  programs.fish.enable = true;

  # Home Manager owns ll; remove the competing NixOS default.
  environment.shellAliases.ll = lib.mkForce null;

  services = {
    tailscale.enable = true;
    openlogi.enable = true;

    udev.extraRules = ''
      # FiiO DAC (JadeAudio JA11 / SNOWSKY Melody) for WebHID access
      ATTRS{idVendor}=="2972", ATTRS{idProduct}=="0126", MODE="0666", GROUP="users"
    '';
  };

  # Tag devices before 73-seat-late.rules applies the active session's ACL.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "usb-hid-uaccess";
      destination = "/etc/udev/rules.d/70-usb-hid-uaccess.rules";
      text = ''
        SUBSYSTEM=="hidraw", SUBSYSTEMS=="usb", TAG+="uaccess"
      '';
    })
  ];

  # Limit parallel builds and tmpfs use to leave RAM for the APU and LLMs.
  nix.settings.max-jobs = lib.mkForce 1;
  boot.tmp.tmpfsSize = lib.mkForce "25%";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  system.stateVersion = "25.11";
}
