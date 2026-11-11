# Flatpak và gói ngoài nixpkgs

Danh sách này dùng để cài lại thủ công các ứng dụng **không do NixOS/Home
Manager quản lý**. Flatpak là mutable state: `nixos-rebuild switch` chỉ cài
phần mềm Flatpak, không cài lại các app bên dưới.

- Flatpak được bật toàn hệ thống trong `modules/nixos/desktop/default.nix`.
- Các app người dùng cài ở **user scope**; riêng Signal cài ở **system scope**.
- Phiên bản ghi ngày **2026-11-11**. Flathub branch `stable` tự cập nhật, nên
  phiên bản thực tế có thể mới hơn.

## Ứng dụng Flatpak

| Ứng dụng | Flatpak ID | Phạm vi | Branch | Phiên bản | Ghi chú |
|---|---|---|---|---|---|
| Brave | `com.brave.Browser` | user | stable | 1.99.55 | Trình duyệt mặc định cho HTTP/HTTPS trong `modules/home/xdg.nix` |
| Discord | `com.discordapp.Discord` | user | stable | 1.0.168 | |
| Visual Studio Code | `com.visualstudio.code` | user | stable | 1.139.1 | |
| Zed | `dev.zed.Zed` | user | stable | v1.27.0 | Bản Nix `pkgsUnstable.zed-editor` vẫn được dùng vì Flatpak không đọc được `/etc/nixos` |
| Obsidian | `md.obsidian.Obsidian` | user | stable | 1.15.0 | |
| LosslessCut | `no.mifi.losslesscut` | user | stable | 3.69.0 | |
| Blender | `org.blender.Blender` | user | stable | 5.2 | Bản LTS 5.2.0 |
| FreeCAD | `org.freecad.FreeCAD` | user | stable | 1.1.4 | |
| KiCad | `org.kicad.KiCad` | user | stable | 10.0.8 | Kèm thư viện Footprints, Symbols, Templates, Packages3D |
| LibrePCB | `org.librepcb.LibrePCB` | user | stable | 2.1.1 | |
| OpenSCAD | `org.openscad.OpenSCAD` | user | stable | 2021.01 | Bản stable mới nhất của upstream |
| Signal Desktop | `org.signal.Signal` | system | stable | 8.34.0 | Cài riêng ở system scope |

KiCad tự cài các extension thư viện khi cài app. Kiểm tra:

```bash
flatpak list --user --runtime --columns=application,branch \
  | grep org.kicad.KiCad.Library
```

Kết quả mong đợi:

```text
org.kicad.KiCad.Library.Footprints     stable
org.kicad.KiCad.Library.Packages3D     stable
org.kicad.KiCad.Library.Symbols        stable
org.kicad.KiCad.Library.Templates      stable
```

## Cài lại

### 1. Thêm Flathub

```bash
flatpak remote-add --if-not-exists --user \
  flathub https://dl.flathub.org/repo/flathub.flatpakrepo

sudo flatpak remote-add --if-not-exists --system \
  flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

### 2. Cài app user scope

```bash
flatpak install --user -y flathub \
  com.brave.Browser \
  com.discordapp.Discord \
  com.visualstudio.code \
  dev.zed.Zed \
  md.obsidian.Obsidian \
  no.mifi.losslesscut \
  org.blender.Blender \
  org.freecad.FreeCAD \
  org.kicad.KiCad \
  org.librepcb.LibrePCB \
  org.openscad.OpenSCAD
```

### 3. Cài app system scope

```bash
sudo flatpak install --system -y flathub org.signal.Signal
```

### 4. Cài thư viện KiCad nếu thiếu

Bình thường không cần bước này vì chúng được cài kèm. Nếu thiếu:

```bash
flatpak install --user -y flathub \
  org.kicad.KiCad.Library.Footprints/x86_64/stable \
  org.kicad.KiCad.Library.Packages3D/x86_64/stable \
  org.kicad.KiCad.Library.Symbols/x86_64/stable \
  org.kicad.KiCad.Library.Templates/x86_64/stable
```

## Cập nhật và kiểm tra

```bash
flatpak update --user
sudo flatpak update --system

flatpak list --user --app --columns=application,name,version,branch,origin
flatpak list --system --app --columns=application,name,version,branch,origin
```

Xoá runtime không còn dùng:

```bash
flatpak uninstall --unused --user
sudo flatpak uninstall --unused --system
```

Luôn truyền `--user` hoặc `--system` khi chạy lệnh Flatpak, vì cả hai
installation đều có remote tên `flathub`. Nếu không, Flatpak sẽ hỏi chọn
installation.

## Dữ liệu ứng dụng

- Dữ liệu app user: `~/.var/app/<flatpak-id>`
- Cài đặt Flatpak user: `~/.local/share/flatpak`
- Cài đặt Flatpak system: `/var/lib/flatpak`

`flatpak uninstall` mặc định **giữ** dữ liệu trong `~/.var/app`. Chỉ dùng
`--delete-data` khi thực sự muốn xoá. Khi chuyển máy, sao lưu `~/.var/app` nếu
cần giữ cấu hình và dữ liệu ứng dụng.

## Gói ngoài nixpkgs nhưng vẫn do Nix quản lý

Các gói sau không lấy trực tiếp từ nixpkgs nhưng được build từ source/AppImage
trong repo. `nixos-rebuild switch` tự cài lại, **không cần cài thủ công**:

| Gói | Nguồn | Định nghĩa |
|---|---|---|
| `misterdownloadmanager` | AppImage upstream | `pkgs/misterdownloadmanager` |
| `lightworks-with-desktop` | Lightworks kèm desktop file/icon | `pkgs/lightworks` |
| `blueman` | nixpkgs, override bỏ autostart trùng | `pkgs/blueman` |
| `fcitx5` | nixpkgs, override bỏ autostart trùng | `pkgs/fcitx5` |

Các công cụ trong `~/.local/bin` do uv/pip/npm hoặc script cá nhân tạo ra là
external user tooling, ngoài phạm vi file này.

## Khôi phục sau khi cài lại máy

1. Cài NixOS và chạy `sudo nixos-rebuild switch --flake git+file:///etc/nixos#think14gryzen`.
2. Thêm remote Flathub như mục 1.
3. Cài app user scope và Signal như mục 2–3.
4. Phục hồi `~/.var/app` từ backup nếu cần giữ dữ liệu app.
5. Chạy `flatpak update --user` và `sudo flatpak update --system`.
