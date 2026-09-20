# Hướng dẫn đo kiểm phần cứng (Hardware Benchmark)

Các kịch bản đo kiểm chuẩn hoạt động độc lập với hệ thống quản lý nguồn. Kịch bản ghi nhận profile và nhiệt độ thực tế nhưng không tự ý can thiệp vào giới hạn công suất, governor CPU hay thiết lập scheduler. Ngoại lệ duy nhất là `oc-curve.sh` sẽ tạm thời chuyển đổi giữa các profile chuẩn của `native-power-profile` để đo A/B rồi khôi phục lại profile ban đầu.

## 1. Các bài đo tiêu chuẩn

| Thành phần | Công cụ | Chỉ số chính | Lưu ý |
|---|---|---|---|
| CPU | `sysbench cpu` | events/s | Chạy kiểm thử ở mức 1 luồng và toàn bộ luồng logic. |
| Bộ nhớ (RAM) | `sysbench memory` | MiB/s | Đọc và ghi tuần tự; giữ nguyên phiên bản và tham số đo. |
| GPU | `glmark2`, `vkmark` | FPS / điểm số | OpenGL và Vulkan là hai API riêng biệt, không thay thế lẫn nhau. |
| Lưu trữ (Disk) | `fio` | Băng thông, IOPS, độ trễ | Chỉ đọc (read-only) trên một tệp thực tế đã có sẵn. |
| LLM | `llama-bench` | tokens/s (prefill và decode) | Sử dụng cấu hình chuẩn `pp512/tg128`, Vulkan, bật Flash Attention. |
| Độ ổn định nhiệt | `stress-ng` | Đạt/Không đạt, biến thiên nhiệt | Dùng để kiểm tra độ ổn định nhiệt độ lâu dài, không dùng làm điểm hiệu năng. |

Lưu ý: Không dùng chỉ số bogo-ops/s của `stress-ng` để so sánh hiệu năng. Đánh giá bài test này dựa trên khả năng hoàn thành, nhiệt độ tối đa và lỗi phát sinh trong kernel log.

## 2. Lệnh thực thi bộ đo kiểm

Mặc định mỗi bài test lặp lại 3 lần. Kết quả lưu tại `/var/tmp/think14gryzen-bench/` (hoặc thư mục chỉ định qua `--output`). Mỗi thư mục chứa log gốc, `summary.tsv`, `telemetry.tsv`, `metadata.txt` và `commands.txt`.

```bash
cd /etc/nixos
bash scripts/bench/cpu.sh --duration 30 --repetitions 3
bash scripts/bench/memory.sh --duration 30 --repetitions 3
bash scripts/bench/gpu.sh --repetitions 3

# Đo LLM với file GGUF cụ thể:
bash scripts/bench/llm.sh \
  --model /mnt/vault/lmstudio-models/unsloth/gemma-3-4b-it-GGUF/gemma-3-4b-it-UD-Q4_K_XL.gguf
```

### Kiểm tra tải nặng kéo dài (Stress test)
Cắm sạc AC trước khi chạy. Thời gian mặc định 10 phút; nên chạy 30 phút để kiểm tra giới hạn nhiệt:

```bash
bash scripts/bench/stress-long.sh --mode combined --duration 1800
bash scripts/bench/gpu.sh --long --duration 1800 --skip-vulkan
```

### Quét đường đặc tính công suất CPU (Power curve)
Đo xung nhịp boost 1 nhân và xung nhịp duy trì toàn nhân trên các profile của `native-power-profile` (`power-saver`, `balanced`, `performance`):

```bash
bash scripts/bench/oc-curve.sh

# Đo riêng cấu hình sustained-build (giữ profile performance nhưng áp mức trần nhiệt/watt thấp hơn qua Ryzenadj):
bash scripts/bench/oc-curve.sh --profile sustained-build
```

Lưu ý: Không bấm chuyển profile trên Waybar khi đang chạy script đo kiểm để tránh làm sai lệch trạng thái ghi nhận tại `/run/native-power-profile/active`.

### Đo kiểm ổ cứng lưu trữ
Script yêu cầu một tệp có sẵn với dung lượng tối thiểu bằng tham số `--size`. Không chạy trên block device trực tiếp:

```bash
nix shell nixpkgs#fio --command bash scripts/bench/storage.sh \
  --file /mnt/vault/lmstudio-models/unsloth/gemma-3-4b-it-GGUF/gemma-3-4b-it-UD-Q4_K_XL.gguf \
  --size 1G --duration 15 --repetitions 3
```

## 3. Đo kiểm tải công việc lập trình (Developer Workloads)

Có hai kịch bản phục vụ so sánh thời gian build mã nguồn:

- `scripts/bench/dev-build.sh`: Đo trên dự án thực tế của người dùng. Phân tách rõ các giai đoạn: build lạnh (cold), build ấm (warm), build tăng tiến (incremental) và no-op. Hỗ trợ chạy trên 1 luồng, 50% luồng và 100% luồng.
- `scripts/bench/pts-developer.sh`: Ủy quyền cho Phoronix Test Suite (chạy các profile như `build-linux-kernel`, `build-llvm`, `build-gcc` hoặc bộ `programmer`).

Xem chi tiết tham số:
```bash
bash scripts/bench/dev-build.sh --help
bash scripts/bench/pts-developer.sh --help
```

Ví dụ đo thời gian build dự án Vite:
```bash
bash scripts/bench/dev-build.sh \
  --project /path/to/checkout \
  --command 'taskset -c 0-$(( {threads} - 1 )) npm run build' \
  --cold-prepare 'rm -rf dist' \
  --incremental-prepare 'touch src/main.tsx' \
  --threads 1,8,16 --repetitions 3
```

## 4. Điểm chuẩn tham chiếu trên think14gryzen

Cấu hình máy trạm tại thời điểm kiểm thử chuẩn (Kernel 7.2, Mesa 26.2, GTT 22 GiB, EEVDF scheduler):
- **LLM Gemma 4B (UD-Q4_K_XL):** Đạt `780.91 t/s` prefill và `32.10 t/s` decode (ngang ~85% trần băng thông bộ nhớ LPDDR5).
- **LLM Qwen 14B (Q4_K_M):** Đạt `129 t/s` prefill và `9.46 t/s` decode trên profile `power-saver`.
- **So sánh engine:** llama.cpp độc lập đạt ~32 t/s decode, trong khi ollama-vulkan đạt ~18 t/s.

## 5. Giới hạn nhiệt độ và Cảnh báo kỹ thuật

- **Trần nhiệt AMD Tjmax:** CPU Ryzen 7 8845H có mức trần Tjmax là `100°C`. Mức nhiệt đo được `95–97°C` khi tải kéo dài là tiệm cận giới hạn phần cứng, phản ánh hiện tượng thắt cổ chai nhiệt độ (thermal throttling).
- **Ngưỡng ngắt an toàn:**
  - Script hiệu năng ghi nhận trạng thái `PASS_THERMAL_LIMITED` và tự động ngắt khẩn cấp ở `98°C`.
  - Script kiểm tra độ ổn định tự động ngắt ở ngưỡng cảnh báo `95°C`.
- **Lỗi trôi giới hạn (`LIMIT_DRIFT`):** Nếu sau khi chạy xong, vi mã firmware tự động đặt lại thông số khác với profile của Ryzenadj, bài test được tính là không đạt (fail).

## 6. Điều kiện bắt buộc cho so sánh A/B

Để kết quả so sánh trước và sau khi thay đổi cấu hình có giá trị, bắt buộc phải cố định các yếu tố sau:
- Nguồn điện cắm sạc AC.
- Profile nguồn đang kích hoạt trong `native-power-profile`.
- Phiên bản kernel, driver Mesa, phiên bản công cụ đo kiểm.
- Mô hình và chuẩn lượng tử hóa (quantization).
- Số luồng CPU, thiết bị GPU chỉ định, số lượng token đầu vào/đầu ra và số lần lặp lại.
- So sánh dựa trên giá trị trung vị (median) của các lần lặp lại tiêu chuẩn.
