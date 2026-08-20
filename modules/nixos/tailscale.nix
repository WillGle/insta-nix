{
  pkgs,
  lib,
  ...
}:
let
  operator = "will";

  # tailscaled is deliberately not started at boot (see wantedBy below), so the
  # GUI has to bring the daemon up itself before it can talk to the local API.
  # Mirrors how proton-vpn is used here: nothing runs until the app is opened.
  tailscaleGui = pkgs.writeShellApplication {
    name = "tailscale-gui";
    runtimeInputs = with pkgs; [
      systemd
      trayscale
    ];
    text = ''
      if ! systemctl is-active --quiet tailscaled.service; then
        # Authorised without a password prompt by the polkit rule below.
        systemctl start tailscaled.service
      fi
      exec trayscale "$@"
    '';
  };

  # Same package, but the menu entry launches the wrapper instead of the bare
  # binary — otherwise the GUI opens against a daemon that isn't running.
  trayscaleApp = pkgs.symlinkJoin {
    name = "trayscale-with-launcher";
    paths = [ pkgs.trayscale ];
    postBuild = ''
      desktop=$out/share/applications/dev.deedles.Trayscale.desktop
      rm -f "$desktop"
      cat > "$desktop" <<EOF
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Trayscale
      GenericName=Tailscale Client
      Comment=Tailscale GUI (starts the daemon on demand, lives in the tray)
      Categories=System;Network;GTK;
      Keywords=tailscale;vpn;
      Icon=dev.deedles.Trayscale
      Exec=${lib.getExe tailscaleGui} %F
      Terminal=false
      SingleMainWindow=true
      X-GNOME-UsesNotifications=true
      EOF
    '';
  };
in
{
  # Tailscale as an on-demand GUI VPN, not a background service.
  #
  # Boot: nothing runs. Opening Trayscale starts tailscaled, closing the window
  # leaves Trayscale in the waybar tray (its `tray-icon` setting defaults on).
  # `systemctl stop tailscaled` (or the tray's quit + stop) shuts it all down.
  environment.systemPackages = [
    trayscaleApp
    tailscaleGui
  ];

  services.tailscale = {
    enable = true;
    openFirewall = true;
    # "client" so exit nodes and subnet routes advertised by other machines work.
    useRoutingFeatures = "client";
    # Lets `will` drive tailscaled over the local API without root — required by
    # Trayscale, which otherwise can only read status.
    extraSetFlags = [ "--operator=${operator}" ];
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  systemd.services = {
    # No autostart: the daemon is started by the GUI wrapper on demand.
    tailscaled.wantedBy = lib.mkForce [ ];

    # Re-apply the operator pref every time the daemon comes up, instead of once
    # at boot (which would drag tailscaled up with it).
    tailscaled-set = {
      wantedBy = lib.mkForce [ "tailscaled.service" ];
      partOf = [ "tailscaled.service" ];
    };
  };

  # Start/stop tailscaled from the GUI without a password prompt.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (
        action.id == "org.freedesktop.systemd1.manage-units" &&
        subject.isInGroup("wheel") &&
        action.lookup("unit") == "tailscaled.service" &&
        ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0
      ) {
        return polkit.Result.YES;
      }
    });
  '';
}
