# Adapted from nixpkgs Lightworks packaging for the official 2026.1 Linux release.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  makeWrapper,
  buildFHSEnv,
  gtk3,
  gdk-pixbuf,
  cairo,
  libjpeg_original,
  glib,
  pango,
  libGLU,
  libGL,
  nvidia_cg_toolkit,
  zlib,
  openssl,
  libuuid,
  alsa-lib,
  udev,
  libjack2,
  freetype,
  libva,
  libvdpau,
  twolame,
  gmp,
  libdrm,
  libpulseaudio,
  sndio,
  libcxx,
  ocl-icd,
}:
let
  fullPath = lib.makeLibraryPath [
    stdenv.cc.cc
    gtk3
    gdk-pixbuf
    cairo
    libjpeg_original
    glib
    pango
    libGL
    libGLU
    nvidia_cg_toolkit
    zlib
    openssl
    libuuid
    alsa-lib
    libjack2
    udev
    freetype
    libva
    libvdpau
    twolame
    gmp
    libdrm
    libpulseaudio
    sndio
    libcxx
    ocl-icd
  ];

  lightworks = stdenv.mkDerivation rec {
    version = "2026.1.0";
    pname = "lightworks";

    src =
      if stdenv.hostPlatform.system == "x86_64-linux" then
        fetchurl {
          url = "https://cdn.lwks.com/releases/${version}/lightworks_${version}_amd64.deb";
          sha256 = "sha256-XQpdUKBW0xgYjhWUxZSJsxY3t/t9IbhJapawgFzIpTc=";
        }
      else
        throw "${pname}-${version} is not supported on ${stdenv.hostPlatform.system}";

    nativeBuildInputs = [
      dpkg
      makeWrapper
    ];

    installPhase = ''
      mkdir -p $out/bin
      substitute usr/bin/lightworks $out/bin/lightworks \
        --replace-fail "/usr/lib/lightworks" "$out/lib/lightworks"
      chmod +x $out/bin/lightworks

      cp -r usr/lib $out

      # /usr/share/fonts is not normally searched
      # This adds it to lightworks' search path while keeping the default
      # using the FONTCONFIG_FILE env variable
      echo "<?xml version='1.0'?>
      <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
      <fontconfig>
          <dir>/usr/share/fonts/truetype</dir>
          <include>/etc/fonts/fonts.conf</include>
      </fontconfig>" > $out/lib/lightworks/fonts.conf

      patchelf \
        --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        $out/lib/lightworks/ntcardvt

      wrapProgram $out/lib/lightworks/ntcardvt \
        --prefix LD_LIBRARY_PATH : ${lib.getLib alsa-lib}/lib:$out/lib/lightworks:${fullPath} \
        --set ALSA_CONFIG_PATH ${alsa-lib}/share/alsa/alsa.conf \
        --set FONTCONFIG_FILE $out/lib/lightworks/fonts.conf

      cp -r usr/share $out/share
    '';

    dontPatchELF = true;
  };

in
buildFHSEnv {
  inherit (lightworks) pname version;

  # Use NixOS ALSA/PipeWire configuration to avoid the unusable sndio fallback.
  # Remove when bundled audio opens the default device at 48 kHz.
  targetPkgs = _pkgs: [
    lightworks
    alsa-lib
  ];

  runScript = "lightworks";

  meta = {
    description = "Professional Non-Linear Video Editor";
    homepage = "https://www.lwks.com/";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    mainProgram = "lightworks";
    maintainers = with lib.maintainers; [
      antonxy
      vojta001
      kashw2
    ];
    platforms = [ "x86_64-linux" ];
  };
}
