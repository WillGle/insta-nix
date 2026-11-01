{ pkgs, ... }:
{
  imports = [ ./base.nix ];

  # One-use bootstrap seed copied into the target root before nixos-install.
  system.activationScripts.plankAuthorizedKeySeed = {
    deps = [ "users" ];
    text = ''
      valid_authorized_keys() {
        [ -s "$1" ] && ${pkgs.openssh}/bin/ssh-keygen -l -f "$1" >/dev/null 2>&1
      }

      seed=/etc/plank/authorized_keys
      target=/home/will/.ssh/authorized_keys

      if [ -e "$target" ] || [ -L "$target" ]; then
        if ! valid_authorized_keys "$target"; then
          echo "FATAL: plank SSH authorized_keys is empty or invalid: $target" >&2
          exit 1
        fi

        chown will:users /home/will/.ssh "$target"
        chmod 700 /home/will/.ssh
        chmod 600 "$target"
      elif [ -e "$seed" ]; then
        if ! valid_authorized_keys "$seed"; then
          echo "FATAL: plank SSH key seed is empty or invalid: $seed" >&2
          exit 1
        fi

        if ! install -d -m 700 -o will -g users /home/will/.ssh ||
          ! install -m 600 -o will -g users "$seed" "$target"; then
          echo "FATAL: could not install plank SSH authorized_keys: $target" >&2
          exit 1
        fi
      else
        echo "FATAL: plank requires a valid SSH key in $seed or $target" >&2
        exit 1
      fi

      rm -f -- "$seed"
    '';
  };
}
