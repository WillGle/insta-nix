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
- `home.nix`: Cấu hình Home Manager riêng của máy (bắt buộc nếu bật giao diện người dùng).
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
    ../../modules/nixos/base.nix
    ../../users/will.nix
    ./system.nix
    # Nạp thêm các module vai trò dùng chung nếu cần:
    # ../../modules/nixos/roles/kubernetes.nix
    # ../../modules/nixos/roles/iac.nix
    # ../../modules/nixos/desktop-integration.nix
    # ../../modules/nixos/ryzen.nix
    # ../../modules/nixos/llm.nix
  ];

  system.stateVersion = "25.11";
}
```

*Lưu ý kiến trúc:* Không import module SSH (`strict.nix` hay `plank.nix`) trong `default.nix`. Module SSH được tiêm trực tiếp qua `flake.nix`.

### 4. Khai báo máy trong `flake.nix`
Hệ thống sử dụng hàm helper `mkHost` trong `flake.nix`. Thêm cấu hình máy mới vào mục `nixosConfigurations`:

```nix
nixosConfigurations.<host-id> = mkHost {
  hostModule = ./hosts/<host-id>/default.nix;
  sshModule = ./modules/nixos/ssh/strict.nix; # hoặc ./modules/nixos/ssh/plank.nix
  enableHome = true;                         # Đặt false nếu là máy chủ/installer không cần Home Manager
  homeModule = ./hosts/<host-id>/home.nix;   # Bắt buộc nếu enableHome = true; bỏ qua nếu false
};
```

## Kiểm tra và Xác minh

Chạy kiểm tra cú pháp flake và biên dịch thử nghiệm cấu hình (dùng tiền tố `path:` để không bắt buộc phải stage tệp vào Git):

```bash
nix flake check --no-build --no-write-lock-file path:/etc/nixos
nixos-rebuild build --flake path:/etc/nixos#<host-id>
```

## Tài liệu liên quan

- [`PLANK_REMOTE_INSTALL.md`](./PLANK_REMOTE_INSTALL.md): Hướng dẫn cài đặt từ xa cho host plank.
- [`../README.md`](../README.md): Tổng quan cấu trúc tài liệu.
