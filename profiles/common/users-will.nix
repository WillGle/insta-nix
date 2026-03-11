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

      CMD="''${1:-toggle}"
      WAIT_SECONDS=0
      NODE_GLOB="/sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode"
      NODE=""

      if [ "$#" -gt 0 ]; then
        shift
      fi

      usage() {
        echo "Usage: toggle-battery-reserve [status|on|off|toggle] [--wait SECONDS]" >&2
      }

      log() {
        echo "[toggle-battery-reserve] $*" >&2
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --wait)
            if [ "$#" -lt 2 ]; then
              usage
              exit 2
            fi
            WAIT_SECONDS="$2"
            shift 2
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            usage
            exit 2
            ;;
        esac
      done

      if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
        log "invalid --wait value: $WAIT_SECONDS"
        exit 2
      fi

      find_node_once() {
        local candidate
        for candidate in $NODE_GLOB; do
          if [ -f "$candidate" ]; then
            printf "%s\n" "$candidate"
            return 0
          fi
        done
        return 1
      }

      resolve_node() {
        if [ -n "$NODE" ] && [ -f "$NODE" ]; then
          printf "%s\n" "$NODE"
          return 0
        fi

        local deadline now candidate
        deadline=$(( $(date +%s) + WAIT_SECONDS ))

        while :; do
          if candidate="$(find_node_once)"; then
            NODE="$candidate"
            printf "%s\n" "$NODE"
            return 0
          fi

          now=$(date +%s)
          if [ "$now" -ge "$deadline" ]; then
            log "conservation_mode node not found (searched $NODE_GLOB)"
            return 1
          fi
          sleep 1
        done
      }

      read_state_raw() {
        local node state

        if ! node="$(resolve_node)"; then
          return 1
        elif ! state="$(cat "$node" 2>/dev/null)"; then
          log "failed to read $node"
          return 1
        fi

        case "$state" in
          0|1) printf "%s\n" "$state" ;;
          *)
            log "unexpected value '$state' in $node"
            return 1
            ;;
        esac
      }

      write_state_raw() {
        local target="$1"
        local node

        if ! node="$(resolve_node)"; then
          return 1
        fi

        if ! printf "%s" "$target" > "$node" 2>/dev/null; then
          log "failed to write $target to $node"
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
