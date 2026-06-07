# Local LLM Guide — think14gryzen (Radeon 780M / Vulkan)

## Purpose

The optimal local-LLM workflow on `think14gryzen`: **fast** (llama.cpp Vulkan, measured ~1.8× the
bundled-ollama engine), **overflow-safe** (auto KV-cache sizing so context never silently spills to
CPU), and **declarative** (the tools ship in the host config).

## TL;DR — three tools + one engine

| Role | Tool | ≈ ollama |
| --- | --- | --- |
| Fetch a model (GGUF) from HuggingFace | `llm-pull` | `ollama pull` |
| Check it fits the GPU at a context | `llm-fit` *(optional)* | — |
| Serve it (auto-sized, OpenAI API) | `llm-run` | `ollama run` |
| Engine | llama.cpp Vulkan (b9309) | (older bundled llama.cpp) |

Models are plain `.gguf` files under `~/.lmstudio/models/` (LM Studio sees them too) — no hidden registry.

## Flow

**① Pull a model (once per model).** Prefers Unsloth **UD** quants (better quality-per-byte at the same speed):

```bash
llm-pull unsloth/gemma-3-12b-it-GGUF          # auto-picks UD-Q4_K_XL
llm-pull bartowski/<Model>-GGUF Q4_K_M        # repo without UD: name the quant
```

Find repos at huggingface.co (search "`<model> GGUF`"); `unsloth/*` (UD quants) then `bartowski/*` are the go-tos.

**② (Optional) Check fit before committing to a big model/context:**

```bash
llm-fit ~/.lmstudio/models/unsloth/gemma-3-12b-it-GGUF/gemma-3-12b-it-UD-Q4_K_XL.gguf 32768
#  → fits f16? if not, the lightest KV-cache type that fixes it, or a GTT-raise hint.
```

**③ Run (each use) — auto-fits and serves:**

```bash
llm-run ~/.lmstudio/models/unsloth/gemma-3-12b-it-GGUF/gemma-3-12b-it-UD-Q4_K_XL.gguf 8192
#  → picks lightest KV that keeps full GPU offload, -fa on; serves http://127.0.0.1:8080
```

**④ Use — point any client at the server:**

- LM Studio / OpenWebUI / editor AI extension: `base_url = http://127.0.0.1:8080/v1`
- `curl http://127.0.0.1:8080/v1/chat/completions -d '{"messages":[{"role":"user","content":"hi"}]}'`
- CLI chat: `llama-cli -m <file> -ngl 999 -fa on`

## Choosing a model (efficiency on a ~102 GB/s bandwidth-bound iGPU)

Decode speed ≈ memory-bandwidth ÷ model-size, so:

- **Prefer Unsloth UD quants** when available — same speed, closer to BF16 quality.
- **Prefer small-active MoE** (e.g. Qwen3-30B-A3B): ~30B knowledge at ~3B speed.
- **Size to the wall:** 4–8B / small-MoE ≈ snappy (≈15–32 t/s); 14B ≈ usable (≈9–10 t/s); 27–32B dense ≈ batch-only.
- Use `llm-fit` to pick the largest model + context that still fits the ~13.6 GiB GTT (raisable via `ttm.pages_limit`).

## LM Studio (secondary GUI)

- **LM Studio** (`lm-studio`): GUI — select the **Vulkan** runtime, keep it updated; it reads the same
  `~/.lmstudio/models/` files (including ones `llm-pull` fetched).
- **ollama was removed 2026-06-07** (measured ~1.8× slower than `llm-run`; nothing depended on it). The
  `llm-ollama-*` wrappers are gone. If you ever want it back, re-add `pkgsUnstable.ollama-vulkan`.

## Verification

```bash
command -v llm-pull llm-fit llm-run llama-server    # all in /run/current-system/sw/bin
llm-run <model.gguf> 8192 &                          # then: curl http://127.0.0.1:8080/v1/models
```

## Related docs

- [`../archive/rocm/README.md`](../archive/rocm/README.md) — ROCm is for ML/HIP compute, NOT LLM
- Local benchmark/method notes: `docs/internal/LLM_BENCHMARK_20260607.md`
