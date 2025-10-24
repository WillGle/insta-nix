{ config, lib, pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    fontconfig.enable = true;

    packages = with pkgs; [
      nerd-fonts.meslo-lg
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts.cjk-sans
      noto-fonts-emoji
      roboto
      unifont
      freefont_ttf
      ipaexfont
      corefonts
    ];

    # (optional) pick defaults, tweak as you like:
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" "FiraCode Nerd Font" ];
      sansSerif = [ "Noto Sans" "Roboto" ];
      serif     = [ "Noto Serif" ];
      emoji     = [ "Noto Color Emoji" ];
     };
  };
}
