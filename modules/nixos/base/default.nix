_: {
  imports = [
    ../desktop/theme.nix
  ];

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

  networking = {
    networkmanager = {
      enable = true;
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
    resolved = {
      enable = true;
      settings.Resolve = {
        DNSSEC = "allow-downgrade";
        DNSOverTLS = "opportunistic";
        LLMNR = false;
        FallbackDNS = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        DNS = "1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4";
        MulticastDNS = false;
      };
    };

    # Shared system services across hosts.
    dbus.enable = true;
    udev.enable = true;
  };

  security.polkit.enable = true;

}
