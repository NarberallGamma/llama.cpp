#!/usr/bin/env bash
# Local Docker stack: llama-server + Open WebUI + nginx.
# Usage: ./run.sh help

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${REPO_ROOT}/deploy/stack"
ENV_FILE="${STACK_DIR}/.env"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Creating ${ENV_FILE} from .env.example"
  cp "${STACK_DIR}/.env.example" "${ENV_FILE}"
fi

mkdir -p "${STACK_DIR}/models" "${STACK_DIR}/data/open-webui"

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

compose() {
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" --project-directory "${STACK_DIR}" "$@"
}

show_help() {
  cat <<EOF
Usage: ./run.sh <command>

Commands:
  help, -h, --help   Show this help
  up                 Pull images and start the stack in the background
  up-fg              Start in the foreground (logs in the terminal)
  down               Stop the stack
  restart            Restart all services
  rescan             Restart llama-server after adding or removing GGUF files
  logs               Follow all logs
  logs-llama         Follow llama-server
  logs-webui         Follow Open WebUI
  logs-proxy         Follow nginx
  ps                 Show container status
  pull               Pull images
  build              Build llama-server from this tree (CUDA Dockerfile)
  models             List GGUF files in MODELS_DIR
  pull-model         Download the default Qwen3.8-27B GGUF into MODELS_DIR
  agent              Launch OpenCode against the local /v1 API (host CLI)
  api-test           GET /v1/models through nginx

URLs after up (defaults):
  Open WebUI   http://${HTTP_BIND:-127.0.0.1}:${HTTP_PORT:-8088}/
  OpenAI API   http://${HTTP_BIND:-127.0.0.1}:${HTTP_PORT:-8088}/v1/
  Health       http://${HTTP_BIND:-127.0.0.1}:${HTTP_PORT:-8088}/health
  Agent CLI    opencode   or   ./run.sh agent

Authorization: Bearer ${LLAMA_API_KEY:-sk-local}

Drop GGUF files into deploy/stack/models/ (or MODELS_DIR), then: ./run.sh rescan
Vision: one subdirectory per model, mmproj*.gguf next to the weights.
EOF
}

CMD="${1:-up}"

case "${CMD}" in
  help|-h|--help)
    show_help
    ;;
  up)
    compose pull
    compose up -d
    echo ""
    echo "Open WebUI: http://${HTTP_BIND:-127.0.0.1}:${HTTP_PORT:-8088}/"
    echo "API:        http://${HTTP_BIND:-127.0.0.1}:${HTTP_PORT:-8088}/v1/  (Bearer ${LLAMA_API_KEY:-sk-local})"
    ;;
  up-fg)
    compose pull
    compose up --build
    ;;
  down)
    compose down
    ;;
  restart)
    compose restart
    ;;
  rescan)
    compose restart llama-server
    echo "llama-server restarted; models dir rescanned"
    ;;
  logs)
    compose logs -f
    ;;
  logs-llama)
    compose logs -f llama-server
    ;;
  logs-webui)
    compose logs -f open-webui
    ;;
  logs-proxy)
    compose logs -f proxy
    ;;
  ps)
    compose ps -a
    ;;
  pull)
    compose pull
    ;;
  build)
    docker build \
      -t local/llama.cpp:server-cuda \
      --target server \
      -f "${REPO_ROOT}/.devops/cuda.Dockerfile" \
      "${REPO_ROOT}"
    echo "Built local/llama.cpp:server-cuda"
    echo "Set LLAMA_IMAGE=local/llama.cpp:server-cuda in deploy/stack/.env and run ./run.sh up"
    ;;
  models)
    src="${MODELS_DIR:-./models}"
    if [[ "${src}" != /* ]]; then
      src="${STACK_DIR}/${src#./}"
    fi
    echo "MODELS_DIR=${src}"
    find "${src}" -iname '*.gguf' 2>/dev/null | sed "s|^${src}/||" || true
    ;;
  pull-model)
    src="${MODELS_DIR:-./models}"
    if [[ "${src}" != /* ]]; then
      src="${STACK_DIR}/${src#./}"
    fi
    mkdir -p "${src}"
    repo="${HF_MODEL_REPO:-unsloth/Qwen3.8-27B-GGUF}"
    file="${HF_MODEL_FILE:-Qwen3.8-27B-UD-Q3_K_XL.gguf}"
    dest="${src}/${file}"
    url="https://huggingface.co/${repo}/resolve/main/${file}"
    echo "Downloading ${repo}/${file}"
    echo "-> ${dest}"
    proxy_args=()
    if [[ -n "${HF_PROXY:-}" ]]; then
      proxy_args=(--proxy "${HF_PROXY}")
    elif ss -ltn 2>/dev/null | grep -q '127.0.0.1:10808'; then
      proxy_args=(--proxy "socks5h://127.0.0.1:10808")
    fi
    curl -L --fail --retry 8 --retry-delay 5 -C - \
      "${proxy_args[@]}" \
      -o "${dest}.partial" \
      "${url}"
    mv "${dest}.partial" "${dest}"
    echo "Saved ${dest}"
    echo "Reload the server: ./run.sh rescan"
    ;;
  agent)
    shift
    if ! command -v opencode >/dev/null 2>&1; then
      echo "opencode is not installed. Arch: pacman -S opencode"
      exit 1
    fi
    cfg="${OPENCODE_CONFIG:-}"
    if [[ -z "${cfg}" ]]; then
      if [[ -f "${STACK_DIR}/opencode.json" ]]; then
        cfg="${STACK_DIR}/opencode.json"
      else
        cfg="${STACK_DIR}/opencode.json.example"
      fi
      export OPENCODE_CONFIG="${cfg}"
    fi
    exec opencode "$@"
    ;;
  api-test)
    curl -sS -H "Authorization: Bearer ${LLAMA_API_KEY:-sk-local}" \
      "http://${HTTP_BIND:-127.0.0.1}:${HTTP_PORT:-8088}/v1/models"
    echo
    ;;
  *)
    echo "Unknown command: ${CMD}"
    echo "Help: ./run.sh help"
    exit 1
    ;;
esac
