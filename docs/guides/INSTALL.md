# Cài NixOS từ Linux hiện có

Cài NixOS lên toàn bộ ổ đĩa từ một distro Linux đang chạy. Không cần USB,
không cần SSH remote install.

## Yêu cầu

- `x86_64`, UEFI (Secure Boot tắt).
- Có internet.
- Chạy bằng `root` hoặc `sudo`.
- Ổ đích sẽ bị **xóa toàn bộ**, không dual boot.
- Nên cắm Ethernet nếu WiFi firmware trên distro cũ không ổn định.

## Cài

```bash
curl -fsSLO https://raw.githubusercontent.com/WillGle/insta-nix/main/install.sh
sudo bash install.sh --disk /dev/nvme0n1
sudo reboot
```

Mặc định cài host `minimal`:

- NixOS console, không desktop, không Home Manager.
- Không swap, không swapfile.
- NetworkManager + user `will` (thuộc `wheel` và `networkmanager`).
- Phù hợp máy cũ/yếu hoặc làm nền trước khi chọn host đầy đủ.

Script sẽ hỏi password cho `will` sau khi cài.

## Tùy chọn

```text
--host NAME   Host trong flake (mặc định: minimal)
--yes         Bỏ xác nhận WIPE
--reboot      Reboot ngay khi xong
--dry-run     Chỉ in kế hoạch, không đụng ổ
```

Ví dụ cài host laptop đầy đủ:

```bash
sudo bash install.sh --disk /dev/nvme0n1 --host laptop
```

Lưu ý: installer tạo `hardware.nix` mới từ phần cứng thực tế. Với
`laptop`, file này thay thế hardware policy hiện tại trong bản checkout
tạm; chỉ dùng khi bạn chấp nhận điều đó.

## Script làm gì

1. Kiểm tra root, UEFI, x86_64, disk và mạng.
2. Xác nhận xóa ổ.
3. Cài Nix nếu máy chưa có.
4. Tải repo từ GitHub về thư mục tạm.
5. `disko`: tạo GPT, ESP 512M, root ext4, mount vào `/mnt`.
6. `nixos-generate-config`: tạo hardware config thật.
7. `nixos-install --flake <repo>#<host>`.
8. Đặt password cho `will`.
9. Copy repo + hardware config vào `/mnt/etc/nixos`.

Sau reboot, `/etc/nixos` đã có sẵn để rebuild:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#minimal
```

## Giới hạn

- Chỉ UEFI; BIOS/legacy không được hỗ trợ.
- Không mã hóa ổ đĩa.
- Không swap.
- Không SSH mặc định trong host `minimal`.
- Luôn kiểm tra `--disk` trước khi chạy; script xóa toàn bộ ổ.
