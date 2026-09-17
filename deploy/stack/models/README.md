# Models directory

Place GGUF weights here. The directory is mounted at `/models` in `llama-server`.

## Single-file text model

```text
models/
  Qwen3-8B-Q4_K_M.gguf
```

## Vision / multimodal

Upstream router expects a subdirectory: weights plus a projector whose name starts with `mmproj`.

```text
models/
  gemma-3-12b-it-Q4_K_M/
    gemma-3-12b-it-Q4_K_M.gguf
    mmproj-F16.gguf
```

After adding or removing files, reload the server: `./run.sh rescan` from the repository root.

Suggested 16 GB text model (agent / chat):

```text
models/
  Qwen3.8-27B-UD-Q3_K_XL.gguf
```

Download from the repo root: `./run.sh pull-model`. Do not add `mmproj*.gguf` beside this file on a 16 GB card.

No model is required for the first `./run.sh up`. `/v1/models` stays empty until a GGUF is present.
