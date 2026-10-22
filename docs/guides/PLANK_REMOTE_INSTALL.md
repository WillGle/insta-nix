# Hướng dẫn cài đặt từ xa cho Plank (Plank Remote Install)

Quy trình cài đặt NixOS lên máy đích `plank` qua mạng mà không sử dụng công cụ `disko`. Máy `plank` được thiết kế làm môi trường bootstrap tối giản (không sử dụng Home Manager, `enableHome = false` trong `flake.nix`).

## Điều kiện tiên quyết

- Biên dịch thành công cấu hình `plank` từ kho lưu trữ này.
- Máy đích đã khởi động vào môi trường cài đặt NixOS (NixOS installer).
- Kết nối mạng thông suốt giữa máy điều khiển và máy đích.
- Tệp seed khóa công khai SSH của Plank tồn tại tại:
  `/etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys`.

## Các bước thực hiện

### 1. Kiểm tra cấu hình trên máy điều khiển
```bash
nix flake check --no-build --no-write-lock-file git+file:///etc/nixos
nix build --no-link --no-write-lock-file \
  git+file:///etc/nixos#nixosConfigurations.plank.config.system.build.toplevel
```

### 2. Phân vùng và gán nhãn đĩa trên máy đích
Yêu cầu bắt buộc về nhãn phân vùng (labels) khớp với cấu hình trong `hosts/plank/storage.nix`:
- `NIXOS_BOOT` cho phân vùng `/boot` (FAT32)
- `NIXOS_SWAP` cho phân vùng Swap
- `NIXOS_ROOT` cho phân vùng `/` (ext4)

Thao tác trên máy đích:
```bash
DISK=/dev/nvme0n1
parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart SWAP linux-swap 1025MiB 17409MiB
parted -s "$DISK" -- mkpart ROOT ext4 17409MiB 100%

mkfs.vfat -F32 -n NIXOS_BOOT "${DISK}p1"
mkswap -L NIXOS_SWAP "${DISK}p2"
mkfs.ext4 -L NIXOS_ROOT "${DISK}p3"

mount /dev/disk/by-label/NIXOS_ROOT /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/NIXOS_BOOT /mnt/boot
swapon /dev/disk/by-label/NIXOS_SWAP
```

### 3. Kiểm tra tệp seed khóa SSH
Tệp seed là bắt buộc cho lần cài đặt đầu tiên để có thể truy cập SSH sau khi khởi động:
```bash
test -s /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys
ssh-keygen -l -f /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys
```

Seed chỉ khởi tạo `/home/will/.ssh/authorized_keys` khi tệp đích chưa tồn tại.
Activation xóa seed trên máy đích sau khi cài khóa thành công hoặc xác nhận
tệp đích đã hợp lệ; seed gốc trên máy điều khiển vẫn được giữ. Sau đó, thay hoặc
thu hồi khóa trực tiếp trong tệp đích; rebuild giữ nguyên các khóa này.
Tệp đích đã tồn tại nhưng rỗng hoặc không hợp lệ sẽ làm activation báo lỗi,
không chép lại hay xóa seed. Xóa tệp đích sau bootstrap cũng không khôi phục
khóa từ seed đã dùng.

### 4. Thực hiện cài đặt

#### Cách 1: Đồng bộ mã nguồn từ máy điều khiển (Khuyên dùng)

Commit các thay đổi cấu hình đã kiểm tra trước khi xuất: `git archive HEAD`
chỉ gửi nội dung commit hiện tại, không gửi tệp ignore, state hay thông tin
xác thực. Dùng thư mục đích mới hoặc rỗng để tránh giữ nguồn cũ. Tiền tố
`path:` bên dưới chỉ áp dụng cho cây nguồn đã xuất này.

```bash
git -C /etc/nixos archive HEAD | \
  ssh root@<ip> 'mkdir -p /mnt/etc/nixos && tar -x -C /mnt/etc/nixos'
ssh root@<ip> 'install -d -m 700 /mnt/etc/plank'
scp /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys \
  root@<ip>:/mnt/etc/plank/authorized_keys
ssh root@<ip> '
  test -s /mnt/etc/plank/authorized_keys &&
  ssh-keygen -l -f /mnt/etc/plank/authorized_keys &&
  nixos-install --root /mnt --flake path:/mnt/etc/nixos#plank
'
```

#### Cách 2: Kéo mã nguồn từ GitHub
```bash
ssh root@<ip> 'install -d -m 700 /mnt/etc/plank'
scp /etc/nixos/.local/remote-install/seed/etc/plank/authorized_keys \
  root@<ip>:/mnt/etc/plank/authorized_keys
ssh root@<ip> '
  test -s /mnt/etc/plank/authorized_keys &&
  ssh-keygen -l -f /mnt/etc/plank/authorized_keys &&
  nixos-install --root /mnt --flake github:<owner>/<repo>#plank
'
```

## Kiểm tra sau khi cài đặt

Kiểm tra kết nối SSH vào máy đích qua cổng tùy chỉnh:
```bash
ssh -p 2222 <user>@<ip>
```

Xác nhận các tệp cục bộ nhạy cảm không bị track trong Git trên máy điều khiển:
```bash
git -C /etc/nixos status --ignored --short
git -C /etc/nixos ls-files | rg -n "remote-install|authorized_keys|\\.local"
```

## Tài liệu liên quan

- [`HOST_ONBOARDING.md`](./HOST_ONBOARDING.md): Quy trình thêm máy mới vào repo.
- [`../README.md`](../README.md): Tổng quan cấu trúc tài liệu.
