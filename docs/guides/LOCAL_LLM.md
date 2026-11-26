# Local LLM on laptop

Run `llama.cpp` Vulkan on the integrated AMD GPU. The tools and 22 GiB GTT
(`ttm.pages_limit=5767168`) are already in the NixOS configuration.

## Tools

| Tool | Purpose |
|---|---|
| `llmfit` | Browse and find hardware-compatible models (TUI/CLI, `--memory 22G` by default) |
| `llm-pull` | Download GGUF from HuggingFace; prefers Unsloth UD and links into the `llmfit` cache |
| `llm-list` | List installed models, sizes, and the router's current model |
| `llm-fit` | Check whether a model fits RAM/VRAM at a given context size |
| Router | `llama-server` at `http://127.0.0.1:8080/v1` |
| `pi` | Coding agent connected directly to the router |

Models default to `/mnt/vault/lmstudio-models/`; override with
`LLM_MODELS_DIR`.

## Workflow

### 1. Find a model

```bash
llmfit                    # TUI
llmfit --cli fit -n 10    # CLI ranking
```

### 2. Download a model

Prefer Unsloth UD quantizations for better quality at the same bandwidth:

```bash
llm-pull unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF   # auto-selects UD-Q4_K_XL
llm-pull bartowski/<Model>-GGUF Q4_K_M               # explicit quantization
```

### 3. Check memory

```bash
llm-fit /mnt/vault/lmstudio-models/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/*.gguf 32768
```

The result shows whether the model fits with an f16 KV cache; if not, it
suggests the lightest compression (`q8`, `q4`).

### 4. Inspect metadata

```bash
llm-list
llm-list --detail <file.gguf>
```

### 5. Call the API

The router runs continuously on port `8080`:

- Base URL: `http://127.0.0.1:8080/v1`
- API key: any value (the server does not check it)

```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"hello"}]}'
```

## Editor integration

| App | Setup |
|---|---|
| `pi` | Config in `~/.pi/agent/`; model `qwen3-coder-30b-a3b` |
| Zed | OpenAI provider + ACP in `~/.config/zed/settings.json` |
| VS Code | Continue/Cline/Roo pointing at `http://127.0.0.1:8080/v1` |

Run the agent in a project:

```bash
cd <project>
pi --model qwen3-coder-30b-a3b
pi -p --model qwen3-coder-30b-a3b "your request"
```

## Maximum speed

1. Use the `performance` profile: `native-power-profile performance` or the
   Waybar button.
2. Plug in AC power.
3. Do not tune GTT manually; the kernel already reserves 22 GiB.

## Model selection for the integrated GPU

Decode speed is limited by LPDDR5 bandwidth (~102 GB/s):

```text
decode (t/s) ≈ memory bandwidth / model size
```

- Prefer MoE models with few active parameters. `Qwen3-Coder-30B-A3B` reaches
  ~29 t/s at 32k context, about 3x faster than a dense 14B with similar
  knowledge.
- Prefer Unsloth UD quantization: close to BF16 at roughly Q4_K_M size.
- 4–8B or small MoE: ~15–33 t/s, good for daily use.
- Dense 14B: ~9–10 t/s.
- Dense 27–32B: very slow; batch work only.

## Policy

- Do not use Ollama; all clients go through the `llama-server` router.
- Do not train/fine-tune on this machine: iGPU often hits MES hangs with
  ROCm PyTorch. Train in the cloud, then export GGUF for local inference.

## Quick checks

```bash
command -v llmfit llm-pull llm-list llm-fit llama-server pi
llm-list
curl http://127.0.0.1:8080/v1/models
```
