# Add a host (Host Onboarding)

Steps for adding a host to the flake. If the machine does not have NixOS yet,
install it with [`INSTALL.md`](./INSTALL.md) first.

## Prerequisites

- Pick a `<host-id>` and `primaryUser.username`.
- Have a hardware config from `nixos-generate-config`.

## 1. Create the host directory

```bash
mkdir -p hosts/<host-id>
```

Create these files:

- `hardware.nix` — `fileSystems`, drivers, and `initrd` from
  `nixos-generate-config`. The installer creates it automatically; edit only
  when adding hardware.
- `default.nix` — identity, composition, and policy:
  - `primaryUser.username`;
  - `networking.hostName`, firewall;
  - additional `fileSystems`/`swapDevices`;
  - user groups and shell;
  - boot loader, Nix resource tuning, udev quirks.
- `packages.nix` (optional) — tools used only on this machine; import it from
  `default.nix`.

Do not create a host `home.nix`. The NixOS module wires Home Manager under
`home-manager.users.${config.primaryUser.username}`. Do not put assets under
the host; keep them next to the module that owns them.

## 2. Write `hosts/<host-id>/default.nix`

```nix
{ ... }:
{
  imports = [
    ./hardware.nix
    ../../base/default.nix
    ../../users/will/default.nix
    ../../modules/system/ssh
    # ../../modules/system/development
    # ../../modules/system/hardware
    # ../../modules/desktop/default.nix
    # ../../modules/system/power
    # ../../modules/system/gaming.nix
  ];

  primaryUser.username = "<username>";
  networking.hostName = "<host-id>";
  system.stateVersion = "25.11";
}
```

The host selects the desktop and hardware it needs. Do not reuse the laptop's
LLM/native-power modules on another machine without checking dependencies.

## 3. Add the host to `flake.nix`

```nix
nixosConfigurations.<host-id> = mkHost {
  hostModule = ./hosts/<host-id>/default.nix;
  # Omit if the machine does not need Home Manager.
  homeModule = ./users/will/home.nix;
};
```

## 4. Validate

`git add` new source files first; the flake Git source does not see untracked
files.

```bash
./scripts/validate.sh
nix build --no-link --no-write-lock-file \
  git+file:///etc/nixos#nixosConfigurations.<host-id>.config.system.build.toplevel
```

Avoid `path:/etc/nixos`; it can copy ignored files into the Nix store.
