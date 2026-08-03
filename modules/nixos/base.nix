{
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./theme.nix ];

  # Locale / Time
  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "vi_VN";
    LC_IDENTIFICATION = "vi_VN";
    LC_MEASUREMENT = "vi_VN";
    LC_MONETARY = "vi_VN";
    LC_NAME = "vi_VN";
    LC_NUMERIC = "vi_VN";
    LC_PAPER = "vi_VN";
    LC_TELEPHONE = "vi_VN";
    LC_TIME = "vi_VN";
  };

  # Core Nix settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = lib.mkAfter [ "https://cache.nixos.org" ];
    trusted-public-keys = lib.mkAfter [
      "cache.nixos.org-1:6NCHdD59X3yjrwW3CvkxuV2L0GyGq5qF5S727Z6IQkQ="
    ];
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    keep-outputs = true;
    keep-derivations = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Use RAM (tmpfs) for /tmp to accelerate compilation/building
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "75%";
    cleanOnBoot = true;
  };
  environment.etc."tmpfiles.d/tmp.conf".text = ''
    q /tmp 1777 root root 3d
    q /var/tmp 1777 root root 30d
  '';

  nixpkgs.config.allowUnfree = true;

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

  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      settings = {
        connection = {
          "ipv4.route-metric" = 50;
          "ipv6.route-metric" = 50;
        };
      };
    };

    firewall.enable = true;
    resolvconf.enable = false;
  };

  services = {
    blueman.enable = true;

    resolved = {
      enable = true;
      dnssec = "allow-downgrade";
      dnsovertls = "opportunistic";
      llmnr = "false";
      fallbackDns = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      extraConfig = ''
        DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
        MulticastDNS=no
      '';
    };

    # Shared system services across hosts.
    dbus.enable = true;
    flatpak.enable = true;
    upower.enable = true;
    udev.enable = true;
    acpid.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
    tailscale.enable = true;
  };

  security.polkit.enable = true;
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
  ];

  environment.etc."resolv.conf".source = "/run/systemd/resolve/stub-resolv.conf";

  system.stateVersion = "25.11";
}
