{ lib, config, pkgs, ... }:

{
  # Filesystems
  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/GENERIC_VAULT_UUID";
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };

  # Environment vars
  environment.variables = {
    GTK_IM_MODULE = lib.mkForce null;
    QT_IM_MODULE  = lib.mkForce null;
  };

  environment.sessionVariables = {
    # UI
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE  = "24";
    QT_FONT_DPI   = "144";
    QT_SCALE_FACTOR = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";

    # Input
    INPUT_METHOD = "fcitx";
    XMODIFIERS   = "@im=fcitx";

    GTK_IM_MODULE = null; # unset để tránh cảnh báo Wayland
    QT_IM_MODULE  = null;
  };

  # Bootloader / kernel
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # amd_pstate nằm ở modules/laptop-power.nix (boot.kernelParams)

  # CPU / firmware
  hardware.cpu.amd.updateMicrocode = true;

  # Virtualization
  virtualisation.docker.enable = true;

  # Locale / Time
  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "vi_VN"; LC_IDENTIFICATION = "vi_VN"; LC_MEASUREMENT = "vi_VN";
    LC_MONETARY = "vi_VN"; LC_NAME = "vi_VN"; LC_NUMERIC = "vi_VN";
    LC_PAPER = "vi_VN"; LC_TELEPHONE = "vi_VN"; LC_TIME = "vi_VN";
  };

  # Fonts (phần desktop sử dụng, nhưng để đồng bộ mình giữ ở base như bản gốc)
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

  # Core services
  services.dbus.enable = true;
  services.openssh.enable = true;
  services.flatpak.enable = true;
  services.upower.enable = true;
  services.udev.enable = true;
  services.acpid.enable = true;
  security.polkit.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # Nix settings (flakes + GC)
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.05";
}
