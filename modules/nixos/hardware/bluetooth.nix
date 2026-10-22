{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Prune trusted, unbonded records only through explicit maintenance;
  # these flags alone do not prove staleness. Preserve paired, bonded,
  # connected, and actively discovered devices.
  # Use busctl to avoid bluetoothctl advertisement-monitor journal spam.
  prune-bluetooth-ghosts = pkgs.writeShellApplication {
    name = "prune-bluetooth-ghosts";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
      systemd
    ];
    text = ''
      prop() {
        busctl --json=short get-property org.bluez "$1" org.bluez.Device1 "$2" 2>/dev/null \
          | sed 's/.*"data":\(.*\)}/\1/'
      }

      # grep returns 1 when no device path matches, which is a normal no-op.
      busctl --no-pager tree org.bluez 2>/dev/null \
        | { grep -oE '/org/bluez/hci[0-9]+/dev_[0-9A-F_]+$' || [ "$?" -eq 1 ]; } \
        | sort -u \
        | while read -r path; do
            paired=$(prop "$path" Paired)
            trusted=$(prop "$path" Trusted)
            bonded=$(prop "$path" Bonded)
            connected=$(prop "$path" Connected)

            # An empty read means the object vanished mid-sweep; skip it rather
            # than treating the blank as "not paired" and deleting a live device.
            [ "$trusted" = "true" ] && [ "$paired" = "false" ] || continue
            [ "$bonded" = "false" ] && [ "$connected" = "false" ] || continue

            adapter="''${path%/dev_*}"
            discovering=$(busctl --json=short get-property org.bluez "$adapter" org.bluez.Adapter1 Discovering 2>/dev/null \
              | sed 's/.*"data":\(.*\)}/\1/')
            [ "$discovering" = "false" ] || continue

            alias=$(prop "$path" Alias | tr -d '"')
            echo "removing never-bonded entry $path ($alias)"
            busctl call org.bluez "$adapter" org.bluez.Adapter1 RemoveDevice o "$path" || true
          done
    '';
  };
in
{
  config = lib.mkIf config.hardware.bluetooth.enable {
    environment.systemPackages = [ prune-bluetooth-ghosts ];

    systemd.services.prune-bluetooth-ghosts = {
      description = "Remove Bluetooth entries that are trusted but never bonded";
      after = [ "bluetooth.service" ];
      requires = [ "bluetooth.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe prune-bluetooth-ghosts;
      };
    };

  };
}
