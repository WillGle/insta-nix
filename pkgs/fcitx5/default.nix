{ pkgs, addons }:

let
  fcitx5WithAddons = pkgs.qt6Packages.fcitx5-with-addons.override { inherit addons; };
in
pkgs.symlinkJoin {
  name = "fcitx5-with-addons-without-autostart";
  paths = [ fcitx5WithAddons ];
  postBuild = ''
    rm -f "$out/etc/xdg/autostart/org.fcitx.Fcitx5.desktop"
  '';
}
