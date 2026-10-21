# Hướng dẫn đo kiểm phần cứng (Hardware Benchmark)

Các bài đo CPU, RAM, GPU, lưu trữ và LLM ghi nhận profile và nhiệt độ nhưng
không thay đổi policy nguồn. `power-profiles.sh` (và stage 1 của `roadmap.sh`)
tạm chuyển native power profile rồi khôi phục profile ban đầu.
`oc-curve.sh` là bài thử riêng có ghi Curve Optimizer −1 vào phần cứng,
kiểm tra readback và reset trước khi khôi phục profile; không dùng nó làm
benchmark baseline thông thường.

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

Monitor từ chối chạy nếu thiếu cảm biến CPU, và yêu cầu cảm biến GPU cho bài
GPU/LLM. Mất cảm biến đang được theo dõi sẽ dừng workload với
`SENSOR_READ_FAIL`. Không coi nhiệt độ `NA` là đã kiểm tra bảo vệ nhiệt.

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

### Bộ đo theo lộ trình tối ưu năm bước

`roadmap.sh` gom các bài đo trên thành năm stage, tạo một thư mục kết quả
chung và tiếp tục sang stage kế tiếp nếu một bài đo thất bại. Stage 1 tạm
thời chuyển qua các native power profile rồi khôi phục profile ban đầu; các
stage còn lại không sửa cấu hình NixOS.

```bash
cd /etc/nixos
bash scripts/bench/roadmap.sh --quick --all

# Chạy đầy đủ, kèm benchmark LLM:
bash scripts/bench/roadmap.sh --all \
  --model /mnt/vault/lmstudio-models/unsloth/gemma-3-4b-it-GGUF/gemma-3-4b-it-UD-Q4_K_XL.gguf

# Chỉ chạy một stage:
bash scripts/bench/roadmap.sh --step 2 --output /tmp/think14gryzen-roadmap-cpu
```

`--quick` dùng các lượt ngắn để kiểm tra nhanh; kết quả chính nằm trong
`summary.tsv`, còn metadata, lệnh đã chạy và log riêng của từng workload nằm
trong cùng thư mục output. Stage 4 được đánh dấu `SKIP` nếu không cung cấp
`--model`.

Roadmap giữ nguyên các cảnh báo `PASS_THERMAL_*`; benchmark con thiếu phép
đo được đánh dấu `PARTIAL` và trả exit code 3. LLM không truyền model vẫn là
`SKIP` tùy chọn. Khi dừng roadmap, wrapper gửi tín hiệu cho benchmark con và
đợi cleanup/khôi phục profile trước khi thoát.

### Kiểm tra tải nặng kéo dài (Stress test)
Cắm sạc AC trước khi chạy. Thời gian mặc định 10 phút; nên chạy 30 phút để kiểm tra giới hạn nhiệt:

```bash
bash scripts/bench/stress-long.sh --mode combined --duration 1800
bash scripts/bench/gpu.sh --long --duration 1800 --skip-vulkan
```

`stress-long.sh` lưu kernel journal trước/sau lượt chạy, chỉ kiểm tra các bản
ghi mới để tìm lỗi phần cứng, kernel, OOM và GPU timeout/reset. Nếu không đọc
được journal, bài kiểm tra journal là `SKIP` và exit code tổng là 3; không
được kết luận máy không có lỗi kernel. Bộ lọc chỉ bao phủ các mẫu lỗi đã định
nghĩa, không thay thế việc xem log gốc. `gpu.sh --long` chỉ PASS khi hoàn tất
thời gian yêu cầu; bị ngắt sớm không được tính là hoàn tất.

### Thử Curve Optimizer −1 (tách biệt với baseline)

`oc-curve.sh` áp CO −1 trên tám core của Hawk Point ở profile `performance`,
chạy CPU0 trong 60 giây rồi 16 luồng trong 480 giây. Script yêu cầu đúng
phần cứng, AC, CPU dưới 70°C, quyền sudo và readback CO ban đầu bằng 0.
Script kiểm tra/reset CO khi thoát. Nếu reset không được xác minh, phải dừng
sử dụng và cold reboot theo cảnh báo của script. Bài này có thay đổi phần
cứng tạm thời; chỉ chạy khi chủ động thử CO.

```bash
bash scripts/bench/oc-curve.sh
```

Script chỉ nhận `--output` và `--help`, không có tùy chọn `--profile`.
Để so sánh profile mà không ghi CO, dùng `power-profiles.sh` bên dưới.

Lưu ý: Không bấm chuyển profile trên Waybar khi đang chạy script đo kiểm để tránh làm sai lệch trạng thái ghi nhận tại `/run/native-power-profile/active`.

### So sánh toàn bộ native power profiles
Để so sánh các preset hiện tại, bao gồm `sustained-build` và `light-use`, dùng runner riêng. Runner này không ghi RyzenAdj/Curve Optimizer, yêu cầu AC, tự dừng ở giới hạn nhiệt cứng và khôi phục profile ban đầu:

```bash
cd /etc/nixos
bash scripts/bench/power-profiles.sh
```

Kết quả mặc định lưu trong `docs/internal/bench/power-profiles/<timestamp>-<pid>/`. Có thể rút ngắn một lượt kiểm tra trước khi chạy full run:

```bash
bash scripts/bench/power-profiles.sh \
  --one-core-seconds 30 --all-core-seconds 180 --cooldown-seconds 60
```

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

PTS interactive yêu cầu terminal và tiện ích `script`; prompt/input được
truyền qua terminal, transcript lưu tại `pts.log`. Chạy không có terminal
thì dùng `--batch`. Build benchmark chuẩn hóa đường dẫn output thành tuyệt
đối; nếu không lấy được thời gian, kết quả là `TIMING_FAIL`, không phải PASS.

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
- **Trôi profile (`PROFILE_DRIFT`):** Runner power profiles/CO kiểm tra tên
  profile trong `/run/native-power-profile/active`. Đây không phải readback
  giới hạn RyzenAdj và không chứng minh firmware giữ nguyên mọi thông số.

## 6. Điều kiện bắt buộc cho so sánh A/B

Để kết quả so sánh trước và sau khi thay đổi cấu hình có giá trị, bắt buộc phải cố định các yếu tố sau:
- Nguồn điện cắm sạc AC.
- Profile nguồn đang kích hoạt trong `native-power-profile`.
- Phiên bản kernel, driver Mesa, phiên bản công cụ đo kiểm.
- Mô hình và chuẩn lượng tử hóa (quantization).
- Số luồng CPU, thiết bị GPU chỉ định, số lượng token đầu vào/đầu ra và số lần lặp lại.
- So sánh dựa trên giá trị trung vị (median) của các lần lặp lại tiêu chuẩn.
