{ pkgs, ... }:
{
  # Shell enabled system-wide (Required for login shell)
  programs.fish.enable = true;

  # Threat model (intentional):
  # `will` is the primary owner-admin account for this personal machine,
  # so near-root capabilities are accepted for operational convenience.
  users.users.will = {
    isNormalUser = true;
    description = "will";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "seat"
      "audio"
      "bluetooth"
      "docker"
      "render"
    ];
  };

  # Passwordless sudo for ryzenadj (manual AMD power tuning)
  # and battery reserve toggle script
  security.sudo.extraRules = [
    {
      users = [ "will" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/ryzenadj";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/toggle-battery-reserve";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "toggle-battery-reserve" ''
      set -euo pipefail

      NODE="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"
      CMD="''${1:-toggle}"

      usage() {
        echo "Usage: toggle-battery-reserve [status|on|off|toggle]" >&2
      }

      read_state_raw() {
        if [ ! -f "$NODE" ]; then
          echo "Error: conservation mode node not found at $NODE" >&2
          return 1
        fi

        local state
        if ! state="$(cat "$NODE" 2>/dev/null)"; then
          echo "Error: failed to read $NODE" >&2
          return 1
        fi

        case "$state" in
          0|1) printf "%s\n" "$state" ;;
          *)
            echo "Error: unexpected value '$state' in $NODE" >&2
            return 1
            ;;
        esac
      }

      write_state_raw() {
        local target="$1"

        if [ ! -f "$NODE" ]; then
          echo "Error: conservation mode node not found at $NODE" >&2
          return 1
        fi

        if ! printf "%s" "$target" > "$NODE" 2>/dev/null; then
          echo "Error: failed to write $target to $NODE" >&2
          return 1
        fi
      }

      print_state_word() {
        local raw="$1"
        case "$raw" in
          1) echo "on" ;;
          0) echo "off" ;;
          *) echo "unknown" ;;
        esac
      }

      case "$CMD" in
        status)
          if RAW_STATE="$(read_state_raw)"; then
            print_state_word "$RAW_STATE"
            exit 0
          fi
          echo "unknown"
          exit 1
          ;;

        on)
          if ! RAW_STATE="$(read_state_raw)"; then
            exit 1
          fi
          if [ "$RAW_STATE" != "1" ]; then
            write_state_raw "1" || exit 1
          fi
          echo "on"
          ;;

        off)
          if ! RAW_STATE="$(read_state_raw)"; then
            exit 1
          fi
          if [ "$RAW_STATE" != "0" ]; then
            write_state_raw "0" || exit 1
          fi
          echo "off"
          ;;

        toggle)
          if ! RAW_STATE="$(read_state_raw)"; then
            exit 1
          fi

          if [ "$RAW_STATE" = "1" ]; then
            write_state_raw "0" || exit 1
            echo "off"
          else
            write_state_raw "1" || exit 1
            echo "on"
          fi
          ;;

        *)
          usage
          exit 2
          ;;
      esac
    '')
  ];
}
