# Fork changes

Wrappers for a single-machine Docker stack around upstream `llama-server`.

This fork does not change the C++ inference code. Upstream updates are merged from `ggml-org/llama.cpp` as usual. Stack files live under `deploy/stack/` so they stay out of the way of upstream Dockerfiles in `.devops/`.

## Stack

One Compose project, one HTTP entry (nginx):

| Path | Upstream |
|------|----------|
| `/` | Open WebUI |
| `/v1/` | `llama-server` OpenAI-compatible API |
| `/health`, `/metrics` | `llama-server` |
| `/llama/` | built-in `llama-server` UI |

The server starts in **router mode** (`--models-dir`). GGUF files can be added later; a model is not required to bring the stack up. Vision models go in a subdirectory with a `mmproj*.gguf` sidecar (upstream layout).

Default image: official `ghcr.io/ggml-org/llama.cpp:server-cuda13` (CUDA 13). CUDA 12: set `LLAMA_IMAGE` to `…:server-cuda`. Building from this tree is optional (`./run.sh build`).

## Quick start

```bash
cp deploy/stack/.env.example deploy/stack/.env
./run.sh up
```

- Chat UI: `http://127.0.0.1:8088/`
- API: `http://127.0.0.1:8088/v1/chat/completions`  
  Header: `Authorization: Bearer <LLAMA_API_KEY>`

Drop GGUF files into `deploy/stack/models/` (or the path in `MODELS_DIR`), then `./run.sh rescan`.

Default local weights (16 GB class cards): Unsloth `Qwen3.8-27B-UD-Q3_K_XL.gguf`. Download:

```bash
./run.sh pull-model
./run.sh rescan
```

Agent loop is **OpenCode on the host** (not another container). It talks to the same loopback API. The CLI needs a real TTY, git, and the project tree:

```bash
# any project directory
opencode
# or
./run.sh agent
# one-shot
opencode run "summarize this repo"
```

Copy `deploy/stack/opencode.json.example` to the OpenCode config path if the defaults need changing. Model id in `/v1/models` is the GGUF stem (`Qwen3.8-27B-UD-Q3_K_XL`).

Do not put mmproj next to this GGUF on a 16 GB card: the projector eats KV room. Vision is a later swap (`MODELS_MAX=1`).

Bind address and port are `HTTP_BIND` / `HTTP_PORT` in `.env`. Defaults listen on loopback only.

## Merge upstream

```bash
git fetch upstream
git merge upstream/master
```
