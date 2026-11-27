{
  lib,
  stdenv,
  fetchgit,
  pkg-config,
  wrapGAppsHook3,
  glib,
  gcr,
  glib-networking,
  gsettings-desktop-schemas,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  xprop,
  dmenu,
  findutils,
  gnused,
  coreutils,
  gst_all_1,
}:

# Stable nixpkgs marks surf broken because it still targets WebKitGTK 4.0.
# This is the upstream 2.1 release with the upstream WebKitGTK 4.1 build fix
# (suckless/surf commit 7f1156f) applied.
stdenv.mkDerivation {
  pname = "surf";
  version = "2.1";

  # tarball is missing file common.h
  src = fetchgit {
    url = "https://git.suckless.org/surf";
    rev = "2.1";
    hash = "sha256-n/RxUmfGmAfnSt2iYJPSDdQVim+HIpsOpr41ryI0Iu0=";
  };

  # Upstream commit 7f1156f: build against WebKitGTK 4.1 for libsoup3.
  postPatch = ''
    substituteInPlace config.mk \
      --replace-fail 'webkit2gtk-4.0' 'webkit2gtk-4.1' \
      --replace-fail 'webkit2gtk-web-extension-4.0' 'webkit2gtk-web-extension-4.1'
  '';

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    glib
    gcr
    glib-networking
    gsettings-desktop-schemas
    gtk3
    libsoup_3
    webkitgtk_4_1
  ]
  ++ (with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
  ]);

  makeFlags = [ "PREFIX=$(out)" ];

  # Add run-time dependencies to PATH. Append them to PATH so the user can
  # override the dependencies with their own PATH. surf is X11-only, so keep
  # the WebKit view on XWayland instead of letting GDK choose Wayland.
  preFixup =
    let
      depsPath = lib.makeBinPath [
        xprop
        dmenu
        findutils
        gnused
        coreutils
      ];
    in
    ''
      gappsWrapperArgs+=(
        --suffix PATH : ${depsPath}
        --set GDK_BACKEND x11
      )
    '';

  meta = {
    description = "Simple web browser based on WebKitGTK";
    homepage = "https://surf.suckless.org";
    license = lib.licenses.mit;
    mainProgram = "surf";
    platforms = webkitgtk_4_1.meta.platforms;
  };
}
