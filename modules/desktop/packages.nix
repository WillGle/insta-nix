{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    bibata-cursors
    brightnessctl
    cliphist
    dunst
    grim
    hyprlock
    hyprpaper
    # Expose notify-send on the interactive PATH; scripts pin their own copy.
    libnotify
    playerctl
    (rofi.override {
      plugins = [
        rofi-calc
        rofi-emoji
      ];
    })
    rofi-power-menu
    slurp
    udiskie
    # Reuse the existing ffmpeg for recording without a privileged KMS helper.
    wf-recorder
    wl-clipboard
    wlr-randr
    xdg-utils

    # Desktop authentication agent.
    lxqt.lxqt-policykit
  ];

  fonts = {
    enableDefaultPackages = true;
    fontconfig.enable = true;

    packages = with pkgs; [
      nerd-fonts.meslo-lg
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono

      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji

      roboto
      unifont
      freefont_ttf
      ipaexfont
      corefonts
    ];

    fontconfig.defaultFonts = {
      monospace = [
        "JetBrainsMono Nerd Font"
        "FiraCode Nerd Font"
      ];
      sansSerif = [
        "Noto Sans"
        "Roboto"
      ];
      serif = [ "Noto Serif" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
