{ pkgs, pkgsUnstable, ... }:
let
  llmOllamaSessionLib = pkgs.writeShellScript "llm-ollama-session-lib" ''
    OLLAMA_HOST_ADDR="127.0.0.1"
    OLLAMA_PORT="11434"
    OLLAMA_URL="http://''${OLLAMA_HOST_ADDR}:''${OLLAMA_PORT}"
    OLLAMA_BIN="${pkgsUnstable.ollama-vulkan}/bin/ollama"
    CURL_BIN="${pkgs.curl}/bin/curl"
    MKDIR_BIN="${pkgs.coreutils}/bin/mkdir"
    MKTEMP_BIN="${pkgs.coreutils}/bin/mktemp"
    CAT_BIN="${pkgs.coreutils}/bin/cat"
    RM_BIN="${pkgs.coreutils}/bin/rm"
    SLEEP_BIN="${pkgs.coreutils}/bin/sleep"
    SETSID_BIN="${pkgs.util-linux}/bin/setsid"
    SS_BIN="${pkgs.iproute2}/bin/ss"
    GREP_BIN="${pkgs.gnugrep}/bin/grep"

    llm_ollama_cleanup() {
      local status=$?

      trap - EXIT INT TERM
      if [ -n "''${SERVER_PID:-}" ]; then
        kill -- "-''${SERVER_PID}" 2>/dev/null || kill "''${SERVER_PID}" 2>/dev/null || true
        wait "''${SERVER_PID}" 2>/dev/null || true
      fi
      if [ -n "''${OLLAMA_LOG:-}" ] && [ -f "''${OLLAMA_LOG}" ]; then
        "''${RM_BIN}" -f "''${OLLAMA_LOG}"
      fi

      exit "$status"
    }

    llm_ollama_prepare() {
      export PATH="${pkgsUnstable.ollama-vulkan}/bin:''${PATH}"
      export OLLAMA_HOST="''${OLLAMA_HOST_ADDR}:''${OLLAMA_PORT}"
      export OLLAMA_MODELS="$HOME/.ollama/models"
      export OLLAMA_VULKAN="1"

      if "''${SS_BIN}" -H -ltn "( sport = :''${OLLAMA_PORT} )" | "''${GREP_BIN}" -q .; then
        echo "[llm-ollama] port ''${OLLAMA_PORT} is already in use; refusing to attach to an unknown server" >&2
        return 1
      fi

      "''${MKDIR_BIN}" -p "''${OLLAMA_MODELS}"
      OLLAMA_LOG="$("''${MKTEMP_BIN}" -t llm-ollama.XXXXXX.log)"
      trap llm_ollama_cleanup EXIT INT TERM
      "''${SETSID_BIN}" "''${OLLAMA_BIN}" serve >"''${OLLAMA_LOG}" 2>&1 &
      SERVER_PID="$!"

      local attempt=0
      while [ "$attempt" -lt 50 ]; do
        if "''${CURL_BIN}" -fsS "''${OLLAMA_URL}/api/version" >/dev/null 2>&1; then
          return 0
        fi
        if ! kill -0 "''${SERVER_PID}" 2>/dev/null; then
          break
        fi
        attempt=$((attempt + 1))
        "''${SLEEP_BIN}" 0.2
      done

      echo "[llm-ollama] failed to start temporary ollama server" >&2
      if [ -f "''${OLLAMA_LOG}" ]; then
        echo "[llm-ollama] startup log:" >&2
        "''${CAT_BIN}" "''${OLLAMA_LOG}" >&2
      fi
      return 1
    }
  '';
in
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

  # Passwordless sudo for approved power wrappers only.
  security.sudo.extraRules = [
    {
      users = [ "will" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/ryzenadj-profile";
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
    (pkgs.writeShellScriptBin "ryzenadj-profile" ''
      set -euo pipefail

      PROFILE="''${1:-}"

      usage() {
        echo "Usage: ryzenadj-profile [performance|balanced|power-saver]" >&2
      }

      case "$PROFILE" in
        performance)
          exec /run/current-system/sw/bin/ryzenadj \
            --stapm-limit=54000 \
            --fast-limit=54000 \
            --slow-limit=54000 \
            --tctl-temp=95 \
            --vrm-current=70000 \
            --vrmmax-current=90000
          ;;

        balanced)
          exec /run/current-system/sw/bin/ryzenadj \
            --stapm-limit=28000 \
            --fast-limit=28000 \
            --slow-limit=28000 \
            --tctl-temp=85
          ;;

        power-saver)
          exec /run/current-system/sw/bin/ryzenadj \
            --stapm-limit=15000 \
            --fast-limit=15000 \
            --slow-limit=15000 \
            --tctl-temp=75
          ;;

        *)
          usage
          exit 2
          ;;
      esac
    '')

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

    (pkgs.writeShellScriptBin "llm-ollama-with" ''
      set -euo pipefail
      . ${llmOllamaSessionLib}

      usage() {
        echo "Usage: llm-ollama-with <command> [args...]" >&2
      }

      if [ "$#" -eq 0 ]; then
        usage
        exit 2
      fi

      llm_ollama_prepare
      "$@"
    '')

    (pkgs.writeShellScriptBin "llm-ollama-run" ''
      set -euo pipefail

      usage() {
        echo "Usage: llm-ollama-run <model> [args...]" >&2
      }

      MODEL="''${1:-}"
      if [ -z "$MODEL" ]; then
        usage
        exit 2
      fi
      shift

      exec llm-ollama-with \
        ${pkgsUnstable.ollama-vulkan}/bin/ollama run "$MODEL" "$@"
    '')

    (pkgs.writeShellScriptBin "llm-ollama-shell" ''
      set -euo pipefail

      SHELL_BIN="''${SHELL:-${pkgs.fish}/bin/fish}"
      if [ ! -x "$SHELL_BIN" ]; then
        SHELL_BIN="${pkgs.fish}/bin/fish"
      fi

      exec llm-ollama-with "$SHELL_BIN" -l
    '')

    (pkgs.writeShellScriptBin "llm-ollama-migrate-models" ''
      set -euo pipefail

      usage() {
        echo "Usage: sudo llm-ollama-migrate-models [user]" >&2
      }

      TARGET_USER="''${1:-will}"
      if [ "$#" -gt 1 ]; then
        usage
        exit 2
      fi

      if [ "$(${pkgs.coreutils}/bin/id -u)" -ne 0 ]; then
        usage
        exit 1
      fi

      USER_ENTRY="$(/run/current-system/sw/bin/getent passwd "$TARGET_USER" || true)"
      if [ -z "$USER_ENTRY" ]; then
        echo "[llm-ollama] user not found: $TARGET_USER" >&2
        exit 1
      fi

      TARGET_HOME="$(printf '%s\n' "$USER_ENTRY" | ${pkgs.coreutils}/bin/cut -d: -f6)"
      DEST_ROOT="$TARGET_HOME/.ollama"
      DEST_MODELS="$DEST_ROOT/models"
      SRC_MODELS=""

      for candidate in /var/lib/private/ollama/models /var/lib/ollama/models; do
        if [ -d "$candidate" ]; then
          SRC_MODELS="$candidate"
          break
        fi
      done

      if [ -z "$SRC_MODELS" ]; then
        echo "[llm-ollama] source model store not found under /var/lib/private/ollama/models or /var/lib/ollama/models" >&2
        exit 1
      fi

      /run/current-system/sw/bin/systemctl stop ollama.service 2>/dev/null || true
      ${pkgs.coreutils}/bin/mkdir -p "$DEST_MODELS"
      ${pkgs.rsync}/bin/rsync -aH "$SRC_MODELS"/ "$DEST_MODELS"/
      ${pkgs.coreutils}/bin/chown -R "$TARGET_USER:users" "$DEST_ROOT"

      READABLE_ENTRY="$(${pkgs.util-linux}/bin/runuser -u "$TARGET_USER" -- ${pkgs.findutils}/bin/find "$DEST_MODELS" -mindepth 1 -maxdepth 2 -readable | ${pkgs.coreutils}/bin/head -n 1 || true)"
      if [ -z "$READABLE_ENTRY" ]; then
        echo "[llm-ollama] migration completed, but readability verification failed for $TARGET_USER" >&2
        exit 1
      fi

      echo "[llm-ollama] migrated model cache to $DEST_MODELS"
      echo "[llm-ollama] verify with: llm-ollama-with ${pkgsUnstable.ollama-vulkan}/bin/ollama list"
    '')
  ];
}
