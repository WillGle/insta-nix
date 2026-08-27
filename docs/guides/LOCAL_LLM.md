# Local LLM Guide — think14gryzen (Radeon 780M / Vulkan)

## Purpose

The optimal local-LLM workflow on `think14gryzen`: **fast** (llama.cpp Vulkan, measured ~1.8× the
bundled-ollama engine), **overflow-safe** (auto KV-cache sizing so context never silently spills to
CPU), and **declarative** (the tools ship in the host config).

## TL;DR — the tool belt

| Role | Tool | Notes |
| --- | --- | --- |
| **Discover** models that fit this hardware | `llmfit` | curated-catalog TUI/CLI, wrapped with `--memory 22G` |
| **Fetch** a GGUF from HuggingFace | `llm-pull` | prefers Unsloth UD quants; mirrors into llmfit's cache and prints detail |
| **Inventory** what is installed | `llm-list` | ground truth: every GGUF + what's being served |
| **Fit-check** a local file at a context | `llm-fit` | exact answer from the real engine |
| **Serve** (auto-sized, OpenAI API) | `llm-run` | lightest KV that keeps full offload, `-fa on` |
| **Agentic coding** on a repo | `pi` | via provider `llama-server` (see below) |
| Engine | llama.cpp Vulkan | tracks nixpkgs-unstable |

Models are plain `.gguf` files under `/mnt/vault/lmstudio-models/` — no hidden
registry. `LLM_MODELS_DIR` overrides this default for another disk or host.
The PCIe 4.0 drive gives ~2× faster model loads.

Measured on this box (gemma-3-4b UD-Q4, performance profile, 2026-08-22 stack
= kernel 7.2 + Mesa 26.2): **pp512 787 t/s, tg128 33.2 t/s** — decode sits at
~85% of the LPDDR5 bandwidth ceiling, so bigger gains come from model choice,
not tuning.

## Flow

**⓪ Discover (when shopping for a model):**

```bash
llmfit                # TUI: browse models scored against this machine
llmfit --cli fit -n 10   # or the classic table
```

The wrapper bakes in `--memory 22G` (autodetect only sees the 4G VRAM carve).
Trust the fit/score columns, NOT the tok/s estimates (optimistic ~2×). Its
"installed" badge only matches names in its own catalog — for what is really
installed, use `llm-list`.

**① Pull a model (once per model).** Prefers Unsloth **UD** quants (better quality-per-byte at the same speed):

```bash
llm-pull unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF   # auto-picks UD-Q4_K_XL
llm-pull bartowski/<Model>-GGUF Q4_K_M               # repo without UD: name the quant
```

Find repos at huggingface.co (search "`<model> GGUF`"); `unsloth/*` (UD quants)
then `bartowski/*` are the go-tos. Downloads resume if interrupted (rerun the
same command). Each pull also drops a flat symlink into
`~/.cache/llmfit/models/` so llmfit sees it.

**①b Inventory anytime:**

```bash
llm-list    # every installed GGUF + size + what llama-server is serving now
llm-list --detail /mnt/vault/lmstudio-models/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/Qwen3-Coder-30B-A3B-Instruct-UD-Q4_K_XL.gguf
# GGUF metadata + tensor types + per-context GPU fit + llmfit catalog estimate
```

The detail view reads GGUF metadata without loading model weights. Its
throughput/score fields are explicitly catalog estimates; measured throughput
belongs to the benchmark logs.

**② (Optional) Check fit before committing to a big model/context:**

```bash
llm-fit /mnt/vault/lmstudio-models/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/*.gguf 32768
#  → fits f16? if not, the lightest KV-cache type that fixes it, or a GTT-raise hint.
```

**③ Run (each use) — auto-fits and serves:**

```bash
llm-run /mnt/vault/lmstudio-models/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/*.gguf 32768 -- --jinja
#  → picks lightest KV that keeps full GPU offload, -fa on; serves http://127.0.0.1:8080
#  → append `-- --jinja` whenever an agent/tool-calling client will connect
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
| **pi** (terminal agent) | provider `llama-server` in `~/.pi/agent/models.json` | **Configured & tested** — see next section |
| **Zed** | `language_models.openai_compatible` provider "llama-server" → agent panel | **Already configured** in `~/.config/zed/settings.json`; first use asks an API key — type anything |
| **VSCode** | Continue / Cline / Roo: provider `openai`, `apiBase: http://127.0.0.1:8080/v1` | Works |
| **Antigravity** | No official BYOK/custom endpoint | Not possible (only ToS-breaking patches) |

Start `llm-run` first; every client above then works against the one server.

## Coding agent on a repo (pi + Qwen3-Coder)

The resident coding model is **Qwen3-Coder-30B-A3B UD-Q4_K_XL** (16.5G MoE,
3.3B active): fits the 22 GiB GTT at **ctx 32768 with f16 KV**, measured
**~29 t/s** decode — verified reading/reasoning over a real repo via pi's
read/grep/edit tools.

```bash
# 1. serve — --jinja is REQUIRED for tool calling (without it the model
#    chats fine but the agent cannot read/edit files):
llm-run /mnt/vault/lmstudio-models/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/*.gguf 32768 -- --jinja

# 2. agent, inside any repo:
cd <repo>
pi --provider llama-server --model qwen3-coder-30b-a3b        # interactive TUI
pi -p --provider llama-server --model qwen3-coder-30b-a3b "…" # one-shot
```

In pi's TUI, `/model` switches between the local model and cloud defaults
(`~/.pi/agent/models.json` hot-reloads). pi itself ships declaratively
(`pkgsUnstable.pi-coding-agent`); Zed can also drive it via `pi-acp`.

## Max speed checklist

1. Performance power profile (Waybar toggle or `sudo ryzenadj-profile performance`).
   The coordinator updates PPD and Ryzenadj together; power-saver caps the APU at 10 W.
2. Plugged into AC.
3. That's it — `-fa on`, full offload, and KV auto-sizing are already `llm-run` defaults.

## Choosing a model (efficiency on a ~102 GB/s bandwidth-bound iGPU)

Decode speed ≈ memory-bandwidth ÷ model-size, so:

- **Prefer Unsloth UD quants** when available — same speed, closer to BF16 quality.
- **Prefer small-active MoE** (e.g. Qwen3-30B-A3B): ~30B knowledge at ~3B speed.
- **Size to the wall:** 4–8B / small-MoE ≈ snappy (≈15–33 t/s); 14B dense ≈ usable (≈9–10 t/s); 27–32B dense ≈ batch-only.
- Use `llm-fit` to pick the largest model + context that still fits the **22 GiB GTT**
  (already raised via `ttm.pages_limit=5767168`).
- Reference points measured on this box: gemma-3-4b UD-Q4 ≈ 33 t/s;
  **Qwen3-Coder-30B-A3B UD-Q4 ≈ 29 t/s at ctx 32k** — a 30B-class MoE running
  ~3× faster than the 14B dense it replaced. MoE is the way on this hardware.

## Runtime policy

- **ollama is gone — keep it that way.** Removed 2026-06-07 (measured ~1.8× slower than
  `llm-run`), it crept back via Zed's agent config and the WisdomTree compose stack, and was
  fully removed host-wide again on 2026-08-22 (user decision: "llm only"). Every consumer now
  goes through llama-server's OpenAI API or the shared GGUF files.

## Fine-tuning / training

**Not on this GPU.** The 2026-08-22 campaign verdict: PyTorch/ROCm training on gfx1103 is
stochastic (~80% instant-fail odds per attempt) — see
[`../archive/rocm/README.md`](../archive/rocm/README.md). The working pipeline is:
**cloud GPU + Unsloth QLoRA → export GGUF → `llm-pull`-style drop into
`/mnt/vault/lmstudio-models/` → serve with `llm-run`.**

## Verification

```bash
command -v llmfit llm-pull llm-list llm-fit llm-run llama-server pi   # all in /run/current-system/sw/bin
llm-list                                             # inventory + serving status
llm-run <model.gguf> 8192 &                          # then: curl http://127.0.0.1:8080/v1/models
```

## Related docs

- [`../archive/rocm/README.md`](../archive/rocm/README.md) — ROCm is for ML/HIP compute, NOT LLM
- Local benchmark/method notes: `docs/internal/LLM_BENCHMARK_20260607.md`
