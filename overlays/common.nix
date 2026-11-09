_final: prev: {
  # Remove the applet service/autostart from the system package; Home Manager
  # starts the applet explicitly with the same build.
  blueman = prev.callPackage ../pkgs/blueman {
    inherit (prev) blueman;
  };

  # Lightworks wrapper that adds the official desktop file and icon.
  lightworks-with-desktop = prev.callPackage ../pkgs/lightworks {
    pkgs = prev;
  };

  # Mister Download Manager, packaged from the upstream AppImage.
  misterdownloadmanager = prev.callPackage ../pkgs/misterdownloadmanager { };
}
