{
  config,
  lib,
  pkgs,
  ...
}:
let
  # A device that is trusted but was never bonded can never connect. Every
  # encrypted profile — HID-over-GATT above all — refuses to read over an
  # unencrypted link, so bluetoothd answers each attempt with "Request attribute
  # has encountered an unlikely error" and never builds an input device. BlueZ
  # still persists the entry, because trusting it is what makes it persistent,
  # so the dead record outlives reboots and shadows the live device in every
  # picker. BLE peripherals rotate their random address on each pairing, so one
  # physical mouse can leave several identically-named corpses behind. Sweep
  # them; nothing is recoverable from an entry that was never bonded.
  #
  # busctl rather than bluetoothctl: bluetoothctl registers and tears down an
  # advertisement monitor on every single invocation, which floods the journal.
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

            # An empty read means the object vanished mid-sweep; skip it rather
            # than treating the blank as "not paired" and deleting a live device.
            [ -n "$paired" ] && [ -n "$trusted" ] || continue
            [ "$trusted" = "true" ] && [ "$paired" = "false" ] || continue

            alias=$(prop "$path" Alias | tr -d '"')
            adapter="''${path%/dev_*}"
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

    systemd.timers.prune-bluetooth-ghosts = {
      description = "Periodic sweep of dead Bluetooth pairings";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        # Catch up after the laptop has been suspended or off past the window.
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };
  };
}
