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
- `system.nix`: Chính sách gắn với máy: `packages.nix`, `graphics.nix`, `user.nix`, và `system.nix` làm điểm nạp. Các vai trò dùng chung nằm trong `modules/system/`.
- `home.nix`: Điểm nạp Home Manager riêng của máy (bắt buộc nếu khai báo `homeModule`). Nạp `../../users/will/home.nix` (đã bao gồm `users/will/packages.nix` và `modules/cli`), `../../modules/desktop/home.nix` cho bộ desktop chuẩn, và `../../modules/system/maintenance/home.nix`.
- Không đặt app asset dưới host. Asset nằm cạnh module sở hữu trong `modules/desktop/<feature>/` hoặc `modules/system/<role>/`.

### 3. Thiết lập điểm nạp chính tại `hosts/<host-id>/default.nix`
Cấu hình tối thiểu:
```nix
{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
    ./network.nix
    ../../base/default.nix
    ../../users/will/default.nix
    ../../modules/system/ssh/strict.nix
    ./system.nix
    # Nạp thêm các vai trò dùng chung nếu cần:
    # ../../modules/system/development
    # ../../modules/system/hardware
    # ../../modules/desktop/default.nix
    # ../../modules/system/power
    # ../../modules/system/gaming.nix
  ];

  system.stateVersion = "25.11";
}
```

*Lưu ý kiến trúc:* Host chọn `modules/system/ssh/strict.nix` nếu cần SSH quản
trị. Baseline `base/`
dùng chung không bật desktop; host chọn desktop và phần cứng cần thiết. Không
dùng module LLM/native-power riêng của laptop cho máy khác nếu chưa kiểm tra phụ
thuộc.

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
./scripts/validate.sh
nix build --no-link --no-write-lock-file \
  git+file:///etc/nixos#nixosConfigurations.<host-id>.config.system.build.toplevel
```

## Tài liệu liên quan

- [`INSTALL.md`](./INSTALL.md): Cài NixOS từ Linux hiện có.
- [`../README.md`](../README.md): Tổng quan cấu trúc tài liệu.
