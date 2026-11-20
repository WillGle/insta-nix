#!/usr/bin/env bash
# Minimal UEFI installer for this flake. The target disk is erased.
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/WillGle/insta-nix}"
REPO_REF="${REPO_REF:-main}"
DISKO_REV="${DISKO_REV:-44761d4f745b95e037458a0e57133c5700c8e320}"
HOST="${HOST:-minimal}"

DISK=""
ASSUME_YES=0
DO_REBOOT=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: sudo bash install.sh --disk /dev/nvme0n1 [options]

Options:
  --disk DEVICE   Target block device (required)
  --host NAME     Host configuration to install (default: minimal)
  --yes           Skip the WIPE confirmation
  --reboot        Reboot after installation
  --dry-run       Print the plan without changing anything
  -h, --help      Show this help

The target disk is erased. UEFI x86_64 only.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --disk)
      [ "$#" -ge 2 ] || die "--disk requires a value"
      DISK="$2"
      shift 2
      ;;
    --host)
      [ "$#" -ge 2 ] || die "--host requires a value"
      HOST="$2"
      shift 2
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --reboot)
      DO_REBOOT=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[ -n "$DISK" ] || {
  usage
  exit 2
}
[ "$(id -u)" -eq 0 ] || die "run as root"
[ "$(uname -m)" = "x86_64" ] || die "only x86_64 is supported"
[ -d /sys/firmware/efi ] || die "UEFI is required"
[ -b "$DISK" ] || die "$DISK is not a block device"
[ "$(lsblk -dno TYPE "$DISK")" = "disk" ] || die "$DISK is not a whole disk"
if [ -n "$(lsblk -nr -o MOUNTPOINT "$DISK" | tr -d '[:space:]')" ]; then
  die "$DISK has mounted partitions"
fi
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v tar >/dev/null 2>&1 || die "tar is required"
curl -fsS --max-time 10 https://github.com >/dev/null 2>&1 ||
  die "no network access to github.com"

log "Target disk:"
lsblk -d -o NAME,SIZE,MODEL "$DISK"

if [ "$ASSUME_YES" -ne 1 ]; then
  printf 'This will erase %s. Type WIPE to continue: ' "$DISK"
  read -r answer
  [ "$answer" = "WIPE" ] || die "aborted"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "dry run: would install host '$HOST' from $REPO_URL to $DISK"
  exit 0
fi

if ! command -v nix >/dev/null 2>&1; then
  log "Installing Nix"
  if command -v systemctl >/dev/null 2>&1; then
    curl -fsSL https://nixos.org/nix/install | sh -s -- --daemon --yes
  else
    curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon --yes
  fi
fi

export NIX_CONFIG="experimental-features = nix-command flakes"
export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck source=/dev/null
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

log "Fetching $REPO_URL ($REPO_REF)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$REPO_URL/archive/refs/heads/$REPO_REF.tar.gz" |
  tar -xz -C "$tmp" --strip-components=1
repo="$tmp"
[ -f "$repo/hosts/$HOST/default.nix" ] || die "unknown host: $HOST"

log "Partitioning and mounting $DISK"
nix run "github:nix-community/disko/$DISKO_REV" -- \
  --mode destroy,format,mount \
  --yes-wipe-all-disks \
  --argstr disk "$DISK" \
  "$repo/install/disko.nix"

install_tools="$repo#nixos-install-tools"

log "Generating hardware configuration"
nix shell "$install_tools" -c nixos-generate-config --root /mnt
install -m 0644 /mnt/etc/nixos/hardware-configuration.nix "$repo/hosts/$HOST/hardware.nix"

log "Installing NixOS host '$HOST'"
nix shell "$install_tools" -c nixos-install \
  --root /mnt \
  --flake "$repo#$HOST" \
  --no-root-passwd

log "Set a password for user 'will'"
nix shell "$install_tools" -c nixos-enter --root /mnt -c 'passwd will'

log "Copying the repository to /mnt/etc/nixos"
mkdir -p /mnt/etc/nixos
cp -a "$repo/." /mnt/etc/nixos/

log "Installation complete"
if [ "$DO_REBOOT" -eq 1 ]; then
  reboot
else
  printf 'Reboot to start NixOS: reboot\n'
fi
