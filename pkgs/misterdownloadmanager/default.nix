{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "misterdownloadmanager";
  version = "0.5.0";

  src = fetchurl {
    url = "https://github.com/anefzaoui/misterdownloadmanager/releases/download/v${version}/MisterDownloadManager-${version}-linux-x86_64.AppImage";
    hash = "sha256-0sfFaCQKk48QEGELSbX+WRp/N9twcKWTc14RuhJaOHg=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/misterdownloadmanager.desktop \
      $out/share/applications/misterdownloadmanager.desktop
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/256x256/apps/misterdownloadmanager.png \
      $out/share/icons/hicolor/256x256/apps/misterdownloadmanager.png
  '';

  meta = with lib; {
    description = "Open-source download manager written in Rust";
    homepage = "https://misterdownloadmanager.com";
    license = licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "misterdownloadmanager";
  };
}
