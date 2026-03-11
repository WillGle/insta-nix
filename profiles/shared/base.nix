{ lib, config, pkgsUnstable, ... }:
let
  hexColor = lib.types.strMatching "^#[0-9a-fA-F]{6}$";
  hasThemeColors = config ? theme && config.theme ? colors;
in
{
  options.theme = {
    colors = lib.mkOption {
      type = lib.types.submodule {
        options = {
          base = lib.mkOption {
            type = hexColor;
            default = "#0d1117";
            description = "Base background color.";
          };
          mantle = lib.mkOption {
            type = hexColor;
            default = "#161b22";
            description = "Elevated surface background.";
          };
          text = lib.mkOption {
            type = hexColor;
            default = "#f0f6fc";
            description = "Primary foreground text.";
          };
          subtext = lib.mkOption {
            type = hexColor;
            default = "#8b949e";
            description = "Secondary/muted text.";
          };
          accent = lib.mkOption {
            type = hexColor;
            default = "#58a6ff";
            description = "Primary accent color.";
          };
          success = lib.mkOption {
            type = hexColor;
            default = "#3fb950";
            description = "Success state color.";
          };
          warning = lib.mkOption {
            type = hexColor;
            default = "#d29922";
            description = "Warning state color.";
          };
          error = lib.mkOption {
            type = hexColor;
            default = "#f85149";
            description = "Error state color.";
          };
          purple = lib.mkOption {
            type = hexColor;
            default = "#bc8cff";
            description = "Secondary accent: purple.";
          };
          cyan = lib.mkOption {
            type = hexColor;
            default = "#39c5cf";
            description = "Secondary accent: cyan.";
          };
        };
      };
      default = { };
      description = "Shared system color palette";
    };
  };

  config = {
    assertions = [
      {
        assertion = hasThemeColors;
        message = "profiles/shared/base.nix requires theme.colors.";
      }
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

    nixpkgs.config.allowUnfree = true;

    console = lib.mkIf hasThemeColors (
      let
        c = config.theme.colors;
      in
      {
        font = "Lat2-Terminus16";
        colors = [
          (lib.removePrefix "#" c.base)
          (lib.removePrefix "#" c.error)
          (lib.removePrefix "#" c.success)
          (lib.removePrefix "#" c.warning)
          (lib.removePrefix "#" c.accent)
          (lib.removePrefix "#" c.purple)
          (lib.removePrefix "#" c.cyan)
          "b1b8c0"
          "6e7681"
          (lib.removePrefix "#" c.error)
          (lib.removePrefix "#" c.success)
          (lib.removePrefix "#" c.warning)
          (lib.removePrefix "#" c.accent)
          (lib.removePrefix "#" c.purple)
          (lib.removePrefix "#" c.cyan)
          (lib.removePrefix "#" c.text)
        ];
      }
    );

    # Shared connectivity defaults
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
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

      ollama = {
        enable = true;
        package = pkgsUnstable.ollama;
        acceleration = "vulkan";
      };
    };

    security.polkit.enable = true;

    environment.etc."resolv.conf".source = "/run/systemd/resolve/stub-resolv.conf";

    system.stateVersion = "25.11";
  };
}
