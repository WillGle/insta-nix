# Quy trình thêm máy mới (Host Onboarding)

Hướng dẫn tích hợp cấu hình của một máy trạm mới vào kho lưu trữ NixOS theo kiến trúc hiện tại.

## Điều kiện tiên quyết

- Xác định định danh duy nhất cho máy mới (`<host-id>`).
- Cấu hình phần cứng hợp lệ tạo bởi `nixos-generate-config`.

## Các bước thực hiện

### 1. Sao chép cấu hình mẫu
```bash
cp -r hosts/_template hosts/<host-id>
```

### 2. Cấu hình các tệp thành phần trong `hosts/<host-id>/`
- `hardware.nix`: Điền thông số phần cứng từ `nixos-generate-config` (hệ điều hành, driver, initrd).
- `network.nix`: Đặt tên máy (`networking.hostName = "<host-id>";`) và cấu hình tường lửa/mạng.
- `storage.nix`: Khai báo hệ thống tệp (`fileSystems`), swap (`swapDevices`) và các phân vùng.
- `system.nix`: Dịch vụ hệ thống, chính sách riêng và các gói phần mềm hệ thống. (Lưu ý: Với máy phức tạp như `think14gryzen`, có thể tách thành thư mục con `system/` gồm `power.nix`, `graphics.nix`, `packages.nix`, v.v.).
- `home.nix`: Điểm nạp Home Manager riêng của máy (bắt buộc nếu khai báo `homeModule`). Nạp `../../users/will/home.nix` (đã bao gồm `users/will/packages.nix` cho ứng dụng cá nhân) và chọn các module giao diện cần dùng; bật Home Manager không tự bật desktop.
- `assets/`: Chứa các script và tệp cấu hình bổ sung do Home Manager quản lý.

### 3. Thiết lập điểm nạp chính tại `hosts/<host-id>/default.nix`
Cấu hình tối thiểu:
```nix
{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../modules/nixos/base/default.nix
    ../../users/will/default.nix
    ../../modules/nixos/services/ssh/strict.nix
    ./system.nix
    # Nạp thêm các module vai trò dùng chung nếu cần:
    # ../../modules/nixos/development/kubernetes.nix
    # ../../modules/nixos/development/iac.nix
    # ../../modules/nixos/desktop/default.nix
    # ../../modules/nixos/hardware/desktop.nix
  ];

  system.stateVersion = "25.11";
}
```

*Lưu ý kiến trúc:* Host chọn chính sách SSH trong `default.nix`: dùng
`modules/nixos/services/ssh/strict.nix` hoặc `plank.nix`. Baseline dùng chung
không bật desktop; host chọn desktop và phần cứng cần thiết. Không dùng module
LLM/native-power riêng của laptop cho máy khác nếu chưa kiểm tra phụ thuộc.

### 4. Khai báo máy trong `flake.nix`
Hệ thống sử dụng hàm helper `mkHost` trong `flake.nix`. Thêm cấu hình máy mới vào mục `nixosConfigurations`:

```nix
nixosConfigurations.<host-id> = mkHost {
  hostModule = ./hosts/<host-id>/default.nix;
  homeModule = ./hosts/<host-id>/home.nix;   # Bỏ qua nếu là máy chủ/installer không cần Home Manager
};
```

## Kiểm tra và Xác minh

Thêm các tệp nguồn host mới vào Git bằng `git add <các-đường-dẫn-nguồn>` trước
khi kiểm tra; flake Git không nhìn thấy tệp chưa được track. Chỉ thêm nguồn cấu
hình dự định quản lý, không thêm state cục bộ hay thông tin xác thực. Tránh
`path:/etc/nixos` vì nó có thể đưa cả tệp bị ignore vào Nix store.

Chạy kiểm tra flake và biên dịch thử nghiệm cấu hình:

```bash
nix flake check --no-build --no-write-lock-file git+file:///etc/nixos
nix build --no-link --no-write-lock-file \
  git+file:///etc/nixos#nixosConfigurations.<host-id>.config.system.build.toplevel
```

## Tài liệu liên quan

- [`PLANK_REMOTE_INSTALL.md`](./PLANK_REMOTE_INSTALL.md): Hướng dẫn cài đặt từ xa cho host plank.
- [`../README.md`](../README.md): Tổng quan cấu trúc tài liệu.
