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
| Engine | llama.cpp Vulkan (tracks nixpkgs-unstable) | (older bundled llama.cpp) |

Models are plain `.gguf` files under `~/.lmstudio/models/` (LM Studio sees them
too) — no hidden registry. Since 2026-08-22 that path is a symlink to
`/mnt/vault/lmstudio-models` (the PCIe 4.0 drive → ~2× faster model loads);
use the `~/.lmstudio/models/...` path everywhere as before.

Measured on this box (gemma-3-4b UD-Q4, performance profile, 2026-08-22 stack
= kernel 7.2 + Mesa 26.2): **pp512 787 t/s, tg128 33.2 t/s** — decode sits at
~85% of the LPDDR5 bandwidth ceiling, so bigger gains come from model choice,
not tuning.

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

- Any OpenAI-compatible client: `base_url = http://127.0.0.1:8080/v1`, API key
  = anything (llama-server doesn't check one).
- `curl http://127.0.0.1:8080/v1/chat/completions -d '{"messages":[{"role":"user","content":"hi"}]}'`
- CLI chat: `llama-cli -m <file> -ngl 999 -fa on`

Useful knobs: `LLM_PORT=8081 llm-run …` for a second model on another port;
`llm-run <model> 8192 -- -np 4` for 4 parallel slots (context is split across
slots); `LLM_HOST=0.0.0.0` only when a container/another device must reach it.

## Editor / app integration (state as of 2026-08-22)

| App | How | Status |
| --- | --- | --- |
| **Zed** | `language_models.openai_compatible` provider "llama-server" → agent panel | **Already configured** in `~/.config/zed/settings.json`; first use asks an API key — type anything |
| **VSCode** | Continue / Cline / Roo: provider `openai`, `apiBase: http://127.0.0.1:8080/v1` | Works |
| **LM Studio** | Shares the same GGUF *files* (its own engine, not llama-server) | Works; pick the Vulkan runtime |
| **Antigravity** | No official BYOK/custom endpoint | Not possible (only ToS-breaking patches) |

Start `llm-run` first; every client above then works against the one server.

## Max speed checklist

1. Performance power profile (waybar toggle, or `sudo ryzenadj-profile performance`
   + `powerprofilesctl set performance`) — power-saver caps the APU at 10 W.
2. Plugged into AC.
3. That's it — `-fa on`, full offload, and KV auto-sizing are already `llm-run` defaults.

## Choosing a model (efficiency on a ~102 GB/s bandwidth-bound iGPU)

Decode speed ≈ memory-bandwidth ÷ model-size, so:

- **Prefer Unsloth UD quants** when available — same speed, closer to BF16 quality.
- **Prefer small-active MoE** (e.g. Qwen3-30B-A3B): ~30B knowledge at ~3B speed.
- **Size to the wall:** 4–8B / small-MoE ≈ snappy (≈15–33 t/s); 14B ≈ usable (≈9–10 t/s); 27–32B dense ≈ batch-only.
- Use `llm-fit` to pick the largest model + context that still fits the **22 GiB GTT**
  (already raised via `ttm.pages_limit=5767168`). Verified: Qwen2.5-Coder-14B Q4_K_M
  fully offloads at ctx 8192 with f16 KV.

## LM Studio (secondary GUI)

- **LM Studio** (`lm-studio`): GUI — select the **Vulkan** runtime, keep it updated; it reads the same
  `~/.lmstudio/models/` files (including ones `llm-pull` fetched).
- **ollama is gone — keep it that way.** Removed 2026-06-07 (measured ~1.8× slower than
  `llm-run`), it crept back via Zed's agent config and the WisdomTree compose stack, and was
  fully removed host-wide again on 2026-08-22 (user decision: "llm only"). Every consumer now
  goes through llama-server's OpenAI API or the shared GGUF files.

## Fine-tuning / training

**Not on this GPU.** The 2026-08-22 campaign verdict: PyTorch/ROCm training on gfx1103 is
stochastic (~80% instant-fail odds per attempt) — see
[`../archive/rocm/README.md`](../archive/rocm/README.md). The working pipeline is:
**cloud GPU + Unsloth QLoRA → export GGUF → `llm-pull`-style drop into
`~/.lmstudio/models/` → serve with `llm-run`.**

## Verification

```bash
command -v llm-pull llm-fit llm-run llama-server    # all in /run/current-system/sw/bin
llm-run <model.gguf> 8192 &                          # then: curl http://127.0.0.1:8080/v1/models
```

## Related docs

- [`../archive/rocm/README.md`](../archive/rocm/README.md) — ROCm is for ML/HIP compute, NOT LLM
- Local benchmark/method notes: `docs/internal/LLM_BENCHMARK_20260607.md`
