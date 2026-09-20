# Hướng dẫn chạy LLM cục bộ — think14gryzen (Radeon 780M / Vulkan)

Tài liệu thiết lập và quy trình vận hành LLM cục bộ trên chip đồ họa tích hợp Radeon 780M:
- **Tốc độ tối đa:** Sử dụng backend `llama.cpp` Vulkan (nhanh hơn ~1.8 lần so với engine của Ollama).
- **Chống tràn bộ nhớ:** Tự động tính toán dung lượng KV-cache để đảm bảo toàn bộ ngữ cảnh nằm trong GPU/GTT, không tràn xuống CPU.
- **Tính khai báo:** Toàn bộ công cụ và cấu hình GTT 22 GiB (`ttm.pages_limit=5767168`) được tích hợp sẵn trong cấu hình NixOS của máy trạm.

## 1. Bảng công cụ quản trị

| Công cụ | Chức năng | Chi tiết |
|---|---|---|
| `llmfit` | Duyệt và tìm mô hình tương thích phần cứng | Giao diện TUI/CLI, tích hợp sẵn tham số `--memory 22G`. |
| `llm-pull` | Tải file GGUF từ HuggingFace | Tự động ưu tiên bản quant Unsloth UD; liên kết vào cache của `llmfit`. |
| `llm-list` | Kiểm tra danh sách mô hình đã cài đặt | Hiển thị toàn bộ tệp GGUF, dung lượng và mô hình router đang phục vụ. |
| `llm-fit` | Đo độ tương thích của mô hình với kích thước ngữ cảnh | Gọi trực tiếp engine `llama-fit-params` để tính toán tràn bộ nhớ. |
| Router nội bộ | Cung cấp OpenAI API Endpoint (`http://127.0.0.1:8080/v1`) | Chạy tiến trình `llama-server` thường trực; phục vụ một mô hình thường trú. |
| `pi` | Agent hỗ trợ lập trình trong dự án | Tích hợp native với router llama.cpp. |

Thư mục lưu trữ mô hình mặc định: `/mnt/vault/lmstudio-models/` (ghi đè bằng biến môi trường `LLM_MODELS_DIR`).

## 2. Quy trình vận hành

### Bước 1: Tìm kiếm mô hình phù hợp
```bash
llmfit                # Giao diện TUI trực quan
llmfit --cli fit -n 10   # Bảng xếp hạng CLI
```

### Bước 2: Tải mô hình về máy
Ưu tiên các bản quant UD (Unsloth Dynamic) để đạt chất lượng cao hơn ở cùng mức băng thông:
```bash
llm-pull unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF   # Tự động chọn UD-Q4_K_XL
llm-pull bartowski/<Model>-GGUF Q4_K_M               # Chỉ định cụ thể tên chuẩn lượng tử
```

### Bước 3: Kiểm tra mức tiêu thụ tài nguyên (Fit-check)
```bash
llm-fit /mnt/vault/lmstudio-models/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/*.gguf 32768
```
Lệnh sẽ trả về: Có vừa bộ nhớ với f16 KV cache không; nếu không, đề xuất kiểu nén KV nhẹ nhất (q8, q4).

### Bước 4: Kiểm tra danh mục và metadata
```bash
llm-list                                             # Danh sách tổng quan
llm-list --detail <ten-file-gguf>                   # Chi tiết layer, tham số, khả năng offload GPU
```

### Bước 5: Gọi API qua Router nội bộ
Router chạy thường trực tại cổng `8080`. Mọi ứng dụng client tương thích OpenAI đều có thể kết nối:
- `base_url`: `http://127.0.0.1:8080/v1`
- `api_key`: Giá trị tùy ý (server không kiểm tra key).

Kiểm tra nhanh qua curl:
```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"xin chao"}]}'
```

## 3. Tích hợp công cụ lập trình

| Ứng dụng | Cách tích hợp | Trạng thái |
|---|---|---|
| **pi** | Tích hợp trực tiếp qua cấu hình `~/.pi/agent/` | Đã cấu hình mô hình `qwen3-coder-30b-a3b` |
| **Zed** | Cấu hình OpenAI provider và ACP trong `~/.config/zed/settings.json` | Đã cấu hình |
| **VSCode** | Cấu hình Continue / Cline / Roo trỏ vào endpoint `http://127.0.0.1:8080/v1` | Sử dụng router nội bộ |

Chạy agent lập trình trong thư mục dự án:
```bash
cd <du-an>
pi --model qwen3-coder-30b-a3b        # Chế độ tương tác TUI
pi -p --model qwen3-coder-30b-a3b "nội dung yêu cầu" # Chạy một lần
```

## 4. Danh mục tối đa tốc độ (Max speed checklist)

1. Chuyển profile nguồn sang `performance`: Chạy `native-power-profile performance` hoặc click nút chuyển trên Waybar.
2. Cắm sạc AC.
3. Không can thiệp thủ công vào GTT: Hệ thống đã nạp sẵn `ttm.pages_limit=5767168` (~22 GiB) ở mức kernel.

## 5. Nguyên tắc lựa chọn mô hình cho iGPU Radeon 780M

Tốc độ decode bị giới hạn trực tiếp bởi băng thông bộ nhớ LPDDR5 (~102 GB/s):
`Tốc độ giải mã (t/s) ≈ Băng thông bộ nhớ / Dung lượng mô hình`.

- **Ưu tiên kiến trúc MoE kích hoạt ít tham số:** Ví dụ `Qwen3-Coder-30B-A3B` (tổng 30B, kích hoạt 3.3B) đạt tốc độ ~29 t/s ở context 32k, nhanh gấp 3 lần so với mô hình dense 14B cùng chất lượng tri thức.
- **Ưu tiên chuẩn lượng tử Unsloth UD:** Đạt chất lượng gần mức BF16 nhưng kích thước chỉ tương đương Q4_K_M.
- **Phân cấp dung lượng:**
  - Mô hình 4–8B hoặc MoE nhỏ: Tốc độ cao (~15–33 t/s), phù hợp dùng hàng ngày.
  - Mô hình Dense 14B: Tốc độ trung bình (~9–10 t/s), đáp ứng mức chấp nhận được.
  - Mô hình Dense 27–32B: Rất chậm, chỉ dùng cho tác vụ xử lý theo lô (batch).

## 6. Chính sách hệ thống

1. **Cấm sử dụng Ollama:** Ollama đã bị loại bỏ hoàn toàn khỏi hệ thống vì chạy chậm hơn ~1.8 lần và gây xung đột cổng. Toàn bộ ứng dụng bắt buộc sử dụng router `llama-server`.
2. **Cấm huấn luyện/fine-tune trên máy trạm:** Chip đồ họa gfx1103 có tỷ lệ lỗi treo phần cứng (MES hang) ~80% khi chạy ROCm PyTorch. Toàn bộ tác vụ huấn luyện phải thực hiện trên Cloud GPU (Unsloth QLoRA), sau đó xuất file GGUF về máy để suy luận.

## 7. Lệnh kiểm tra hệ thống

```bash
command -v llmfit llm-pull llm-list llm-fit llama-server pi
llm-list
curl http://127.0.0.1:8080/v1/models
```
