{ pkgs }:

let
  lightworks = pkgs.callPackage ./package.nix { };
in
# Lightworks wrapper that adds the official .desktop file and icon,
# missing from nixpkgs buildFHSUserEnv by default.
pkgs.symlinkJoin {
  name = "lightworks-with-desktop";
  paths = [
    lightworks
    (pkgs.runCommand "lightworks-desktop" { lw = lightworks; } ''
              mkdir -p $out/share/applications $out/share/icons/hicolor/512x512/apps
              rootfs=$(grep -o '/nix/store/[^" ]*-fhsenv-rootfs' $lw/bin/lightworks | head -n1)
              if [ -n "$rootfs" ] && [ -f "$rootfs/usr/share/lightworks/Icons/App.png" ]; then
                cp "$rootfs/usr/share/lightworks/Icons/App.png" $out/share/icons/hicolor/512x512/apps/lightworks.png
              fi
              cat > $out/share/applications/lightworks.desktop <<EOF
      [Desktop Entry]
      Version=1.0
      Name=Lightworks
      GenericName=Video Editor
      Comment=Cross-platform film & video editor
      Exec=lightworks
      Icon=lightworks
      Terminal=false
      Type=Application
      Categories=AudioVideo;AudioVideoEditing;
      StartupWMClass=Ntcardvt
      EOF
    '')
  ];
}
