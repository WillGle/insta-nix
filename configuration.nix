{ lib, config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/GENERIC_VAULT_UUID";
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };

  # ───────── Environment vars ─────────
  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE  = "24";

    # IME for all toolkits
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE  = "fcitx";
    XMODIFIERS    = "@im=fcitx";

    # your current Qt scaling settings
    QT_FONT_DPI = "144";
    QT_SCALE_FACTOR = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";
  };

  # ───────── Bootloader ─────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "amd_pstate=active" ];

  # ───────── CPU / FW ─────────
  hardware.cpu.amd.updateMicrocode = true;

  # ───────── Power ─────────
  powerManagement.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_BOOST_ON_AC = 1;
      CPU_MAX_PERF_ON_AC = "100";
      CPU_MIN_PERF_ON_AC = "20";

      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_BOOST_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = "35";
      CPU_MIN_PERF_ON_BAT = "5";

      PLATFORM_PROFILE_ON_AC  = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # STOP_CHARGE_THRESH_BAT0 = "1"; # ~80%
      STOP_CHARGE_THRESH_BAT0 = "0";   # full
    };
  };

  # ───────── Networking ─────────
  networking = {
    hostName = "Laptop";
    networkmanager = { enable = true; dns = "systemd-resolved"; };
    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [ "proton0" "ipv6leakintrf0" ];
    };
    resolvconf.enable = false;
  };

  services.resolved = {
    enable      = true;
    dnssec      = "false";
    fallbackDns = [ "1.1.1.1" "8.8.8.8" ];
    domains     = [ "~." ];
  };

  environment.etc."resolv.conf".source = "/run/systemd/resolve/stub-resolv.conf";

  # ───────── Locale / Time ─────────
  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "vi_VN"; LC_IDENTIFICATION = "vi_VN"; LC_MEASUREMENT = "vi_VN";
    LC_MONETARY = "vi_VN"; LC_NAME = "vi_VN"; LC_NUMERIC = "vi_VN";
    LC_PAPER = "vi_VN"; LC_TELEPHONE = "vi_VN"; LC_TIME = "vi_VN";
  };

  # ───────── Fonts ─────────
  fonts.enableDefaultPackages = true;
  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [
    nerd-fonts.meslo-lg
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    roboto
    unifont
    freefont_ttf
    ipaexfont
    corefonts
  ];

  # ───────── Input ─────────
  services.xserver.xkb = { layout = "us"; variant = ""; };

  i18n.inputMethod = {
    enable  = true;
    type    = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-unikey fcitx5-qt fcitx5-gtk fcitx5-configtool ];
  };

  # ───────── Virtualization ─────────
  virtualisation.docker.enable = true;

  # ───────── GPU / Display ─────────
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vulkan-loader vulkan-tools vulkan-validation-layers
      libva libva-utils vaapiVdpau
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      libva libva-utils vaapiVdpau
    ];
  };

  services.xserver = { enable = true; videoDrivers = [ "amdgpu" ]; };

  # ───────── Display Manager / WM ─────────
  programs.hyprland.enable = true;

  # Make Hyprland visible to SDDM as a Wayland session
  services.displayManager.sessionPackages = [ pkgs.hyprland ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sugar-dark";
  };

  # Tell the display manager which session to start by default
  services.displayManager.defaultSession = "hyprland";

  # ───────── Gaming ─────────
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };
  programs.gamemode.enable = true;
  security.rtkit.enable = true;

  # ───────── XDG Portals ─────────
  xdg.portal = {
    enable = true;
    wlr.enable = false; # prefer Hyprland-specific portal
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  # ───────── User ─────────
  users.users.will = {
    isNormalUser = true;
    description = "will";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager" "wheel" "video" "input"
      "seat" "audio" "bluetooth" "docker"
    ];
    packages = with pkgs; [ ];
  };

  # ───────── Shell / Prompt ─────────
  programs.fish.enable = true;
  programs.starship.enable = true;

  # ───────── Audio ─────────
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = false;
  };

  # ───────── Bluetooth ─────────
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ───────── Core Services ─────────
  services.dbus.enable = true;
  services.openssh.enable = true;
  services.flatpak.enable = true;
  services.upower.enable = true;
  services.udev.enable = true;
  services.acpid.enable = true;
  security.polkit.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # sudo rule for tlp
  security.sudo.extraRules = [{
    users = [ "will" ];
    commands = [{ command = "/run/current-system/sw/bin/tlp"; options = [ "NOPASSWD" ]; }];
  }];

  # ───────── Packages ─────────
  environment.systemPackages = with pkgs; [
    # Wayland & desktop
    alacritty
    brightnessctl
    mission-center
    waybar

    # WM helpers
    dunst
    hyprland
    hyprpaper
    hyprshot
    rofi-wayland
    sway
    swayidle
    swaylock
    wofi

    # Utilities
    acpid
    cliphist
    eza
    fastfetch
    htop
    kanshi
    lm_sensors
    nautilus
    pciutils
    playerctl
    usbutils
    wget
    wl-clipboard
    wob
    xdg-utils
    grim
    slurp
    udiskie
    dosfstools
    exfatprogs
    ntfs3g
    ffmpeg
    v4l-utils
    libheif
    libavif

    # Audio & network
    alsa-utils
    bind
    blueman
    networkmanagerapplet
    pavucontrol
    pipewire
    protonvpn-gui
    upower

    # SDDM themes
    catppuccin-sddm
    sddm-astronaut
    sddm-chili-theme
    sddm-sugar-dark

    # Apps
    adwaita-icon-theme
    brave
    deadbeef
    docker
    firefox
    gsimplecal
    obs-studio
    obsidian
    signal-desktop
    vscode
    steam
    wpsoffice
    vlc
    gnome-disk-utility
    xournalpp
    libreoffice
    guvcview
    gthumb
    nomacs

    # Gaming tools
    mesa-demos
    vulkan-tools
    libva-utils
    steam-run
    mangohud

    # Input (VN)
    fcitx5-configtool
    fcitx5-unikey

    # Shell & prompt
    fish
    git
    gnome-console
    starship
    bash
    gawk

    # Cursors
    bibata-cursors
  ];

  # ───────── User services ─────────
  systemd.user.services.kanshi = {
    description = "Kanshi monitor profile daemon";
    wantedBy = [ "default.target" ];
    after     = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.kanshi}/bin/kanshi";
      Restart = "on-failure";
    };
  };

  systemd.user.services.waybar = {
    description = "Waybar";
    wantedBy = [ "default.target" ];
    after    = [ "default.target" ];
    serviceConfig = {
      ExecStartPre = "${pkgs.bash}/bin/sh -c 'for i in $(seq 1 100); do ${pkgs.hyprland}/bin/hyprctl -j monitors >/dev/null 2>&1 && exit 0; sleep 0.05; done; echo hyprctl not ready; exit 1'";
      ExecStart   = "${pkgs.waybar}/bin/waybar";
      Restart     = "on-failure";
      RestartSec  = 1;
      Environment = [
        "XDG_CURRENT_DESKTOP=Hyprland"
        "SHELL=${pkgs.bash}/bin/bash"
        "PATH=/run/current-system/sw/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:${pkgs.gawk}/bin"
      ];
    };
  };

# ───────── Nix (flakes) ─────────
nix.settings = {
  experimental-features = [ "nix-command" "flakes" ];
  auto-optimise-store = true;
};
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 14d";
};

  # ───────── Nix settings ─────────
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.05";
}
