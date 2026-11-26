# Flatpak and non-nixpkgs packages

Use this list to reinstall apps **not managed by NixOS/Home Manager**. Flatpak
is mutable state: `nixos-rebuild switch` installs the Flatpak runtime but does
not reinstall these apps.

- Flatpak is enabled system-wide in `modules/desktop/default.nix`.
- User apps are installed in **user scope**; Signal uses **system scope**.
- Versions recorded on **2026-11-11**; the `stable` branch updates itself.

## Apps

| App | Flatpak ID | Scope | Version | Notes |
|---|---|---|---|---|
| Brave | `com.brave.Browser` | user | 1.99.55 | Default for HTTP/HTTPS |
| Discord | `com.discordapp.Discord` | user | 1.0.168 | |
| VS Code | `com.visualstudio.code` | user | 1.139.1 | |
| Obsidian | `md.obsidian.Obsidian` | user | 1.15.0 | |
| LosslessCut | `no.mifi.losslesscut` | user | 3.69.0 | |
| Blender | `org.blender.Blender` | user | 5.2 | LTS 5.2.0 |
| FreeCAD | `org.freecad.FreeCAD` | user | 1.1.4 | |
| KiCad | `org.kicad.KiCad` | user | 10.0.8 | Includes libraries |
| LibrePCB | `org.librepcb.LibrePCB` | user | 2.1.1 | |
| OpenSCAD | `org.openscad.OpenSCAD` | user | 2021.01 | Current upstream stable |
| Signal | `org.signal.Signal` | system | 8.34.0 | Separate install |

## Reinstall

### 1. Add Flathub

```bash
flatpak remote-add --if-not-exists --user \
  flathub https://dl.flathub.org/repo/flathub.flatpakrepo

sudo flatpak remote-add --if-not-exists --system \
  flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

### 2. User apps

```bash
flatpak install --user -y flathub \
  com.brave.Browser \
  com.discordapp.Discord \
  com.visualstudio.code \
  md.obsidian.Obsidian \
  no.mifi.losslesscut \
  org.blender.Blender \
  org.freecad.FreeCAD \
  org.kicad.KiCad \
  org.librepcb.LibrePCB \
  org.openscad.OpenSCAD
```

### 3. Signal

```bash
sudo flatpak install --system -y flathub org.signal.Signal
```

### 4. KiCad libraries

KiCad normally installs them. If missing:

```bash
flatpak install --user -y flathub \
  org.kicad.KiCad.Library.Footprints/x86_64/stable \
  org.kicad.KiCad.Library.Packages3D/x86_64/stable \
  org.kicad.KiCad.Library.Symbols/x86_64/stable \
  org.kicad.KiCad.Library.Templates/x86_64/stable
```

Check:

```bash
flatpak list --user --runtime --columns=application,branch \
  | grep org.kicad.KiCad.Library
```

## Update and clean up

```bash
flatpak update --user
sudo flatpak update --system

flatpak list --user --app --columns=application,name,version,branch,origin
flatpak list --system --app --columns=application,name,version,branch,origin

flatpak uninstall --unused --user
sudo flatpak uninstall --unused --system
```

Always pass `--user` or `--system`: both installations have a remote named
`flathub`, so Flatpak would otherwise ask which one to use.

## Data

- User apps: `~/.var/app/<flatpak-id>`
- User Flatpak: `~/.local/share/flatpak`
- System Flatpak: `/var/lib/flatpak`

`flatpak uninstall` keeps data in `~/.var/app`; use `--delete-data` only when
you really want to remove it. Back up `~/.var/app` when moving machines.

## Non-nixpkgs packages managed by Nix

These build from source/AppImage in the repo; `nixos-rebuild switch` installs
them automatically:

| Package | Source | Definition |
|---|---|---|
| `misterdownloadmanager` | Upstream AppImage | `pkgs/misterdownloadmanager` |
| `lightworks-with-desktop` | Lightworks + desktop file/icon | `pkgs/lightworks` |
| `blueman` | nixpkgs, duplicate autostart removed | `pkgs/blueman` |
| `fcitx5` | nixpkgs, duplicate autostart removed | `pkgs/fcitx5` |

Tools in `~/.local/bin` created by uv/pip/npm or personal scripts are external
user tooling and outside this file.

## Restore after reinstall

1. Install NixOS and run
   `sudo nixos-rebuild switch --flake git+file:///etc/nixos#laptop`.
2. Add the Flathub remotes.
3. Install the user apps and Signal.
4. Restore `~/.var/app` if you need app data.
5. Run `flatpak update --user` and `sudo flatpak update --system`.
