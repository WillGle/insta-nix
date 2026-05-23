# Local LLM Notes

## Purpose

This guide records the basic local LLM setup on `think14gryzen`.

## When to use

Use this guide when you want a quick reminder for the local CLI or GUI path for model testing.

## Prerequisites

- You are on `think14gryzen`.
- `ollama` or `LM Studio` is installed in the current system.

## Steps

1. Start the Ollama service if needed.

   ```bash
   ollama serve
   ```

2. Run a model from the CLI.

   ```bash
   ollama run qwen3.5:9b
   ```

3. Start the GUI if you prefer it.

   ```bash
   lm-studio
   ```

Keep the machine limits in mind:

- Prefer 7B to 9B quantized models for normal interactive use.
- Treat larger models as a separate performance and stability exercise.

## Verification

Confirm that the CLI starts a model or that `LM Studio` opens successfully.

## Related docs

- [`AMD_PERF_SUITE.md`](./AMD_PERF_SUITE.md)
- [`../README.md`](../README.md)
