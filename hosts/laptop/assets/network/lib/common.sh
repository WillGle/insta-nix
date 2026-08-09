#!/usr/bin/env bash
# NetworkManager query helpers shared by rofi-network and waybar-network-info.
#
# Both programs asked nmcli the same nine questions and each kept its own copy
# of the answer. The copies drifted: wifi_iface below carries the fix for device
# names containing an escaped colon, which waybar-network-info was missing.
#
# Two same-named helpers are deliberately NOT here, because the two callers need
# different contracts from them:
#   active_ethernet      rofi renders "name on device", waybar parses "name<TAB>device"
#   active_wifi_ap_line  waybar additionally requests the RATE field, which shifts
#                        every field position in the colon-separated line
#
# nmcli -t escapes literal colons inside values as "\:", which collides with the
# field separator. The helpers mask them to \x01 before awk splits, then restore.

wifi_iface() {
  nmcli -t -f DEVICE,TYPE device | sed 's/\\:/\x01/g' | awk -F: '$2 == "wifi" && !found { gsub(/\x01/, ":", $1); print $1; found = 1 }'
}

wifi_enabled() {
  [ "$(nmcli radio wifi)" = "enabled" ]
}

signal_icon() {
  local signal="${1:-0}"
  if ! [[ "$signal" =~ ^[0-9]+$ ]]; then
    signal=0
  fi

  if [ "$signal" -ge 80 ]; then
    printf '󰤨'
  elif [ "$signal" -ge 60 ]; then
    printf '󰤥'
  elif [ "$signal" -ge 40 ]; then
    printf '󰤢'
  elif [ "$signal" -ge 20 ]; then
    printf '󰤟'
  else
    printf '󰤯'
  fi
}

band_label() {
  local freq="${1%% *}"
  if ! [[ "$freq" =~ ^[0-9]+$ ]]; then
    printf '?'
    return
  fi

  if [ "$freq" -ge 5925 ]; then
    printf '6 GHz'
  elif [ "$freq" -ge 5000 ]; then
    printf '5 GHz'
  else
    printf '2.4 GHz'
  fi
}

security_label() {
  local security="${1:-}"
  if [ -z "$security" ] || [ "$security" = "--" ]; then
    printf 'Open'
  else
    printf '%s' "$security"
  fi
}

active_wifi_connection() {
  local iface="$1"
  nmcli -t -f NAME,UUID,TYPE,DEVICE connection show --active \
    | sed 's/\\:/\x01/g' \
    | awk -F: -v target="$iface" '$3 == "802-11-wireless" && $4 == target && !found {
        gsub(/\x01/, ":", $1); gsub(/\x01/, ":", $4);
        print $1 "\t" $2 "\t" $4; found = 1
      }'
}

connection_ssid() {
  local uuid="$1"
  local name="${2:-}"
  local ssid=""

  if [ -n "$uuid" ]; then
    ssid="$(nmcli -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null | sed -n '1p' || true)"
  fi

  if [ -n "$ssid" ]; then
    printf '%s' "$ssid"
  elif [ -n "$name" ]; then
    printf '%s' "$name"
  fi
}

current_gateway() {
  local iface="$1"
  nmcli -g IP4.GATEWAY device show "$iface" 2>/dev/null | sed -n '1p'
}

current_dns() {
  local iface="$1"
  nmcli -g IP4.DNS device show "$iface" 2>/dev/null \
    | awk 'NF { printf "%s%s", sep, $0; sep = ", " } END { printf "\n" }'
}
