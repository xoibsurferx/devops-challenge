#!/usr/bin/env bash
# Terraform (minikube + addons + Argo CD), then kubectl apply local app overlay.
# The app image is docker.io/xoibsurferx/devops-challenge:latest from Docker Hub (see kustomize). Optional --local-image builds from this repo.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-"$ROOT_DIR/terraform/local-minikube"}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
# Only used with --local-image; tag is separate from the :latest Kustomize default
IMAGE_NAME="${IMAGE_NAME:-docker.io/xoibsurferx/devops-challenge:local}"
KUSTOMIZE_APP_DIR="${KUSTOMIZE_APP_DIR:-"$ROOT_DIR/kustomize/app/overlays/local"}"
SKIP_TERRAFORM="${SKIP_TERRAFORM:-false}"
BUILD_LOCAL_IMAGE="${BUILD_LOCAL_IMAGE:-false}"
SKIP_KUSTOMIZE="${SKIP_KUSTOMIZE:-false}"

log() { printf '==> %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-terraform) SKIP_TERRAFORM=true; shift ;;
    --local-image) BUILD_LOCAL_IMAGE=true; shift ;;
    --skip-kustomize) SKIP_KUSTOMIZE=true; shift ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "  --skip-terraform  Assume cluster already exists; skip terraform apply"
      echo "  --local-image     Build and load an image from the repo (tag IMAGE_NAME, default :local) instead of using docker.io/.../latest from Hub"
      echo "  --skip-kustomize  Skip kubectl apply -k (terraform and optional --local-image only)"
      echo "  Env: TF_DIR, MINIKUBE_PROFILE, IMAGE_NAME, KUSTOMIZE_APP_DIR, MINIKUBE_DRIVER, BUILD_LOCAL_IMAGE=1 (same as --local-image)"
      exit 0
      ;;
    *) log "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ "${BUILD_LOCAL_IMAGE}" == "1" || "${BUILD_LOCAL_IMAGE}" == "true" ]]; then
  BUILD_LOCAL_IMAGE=true
fi

for c in minikube kubectl terraform; do
  command -v "$c" >/dev/null 2>&1 || { log "Required command not found: $c"; exit 1; }
done

if [[ "$SKIP_TERRAFORM" != "true" ]]; then
  log "terraform init: $TF_DIR"
  (cd "$TF_DIR" && terraform init -input=false)
  AP_ARGS=(apply -input=false)
  if [[ -n "${TF_APPLY_FLAGS:-}" ]]; then
    # shellcheck disable=SC2206
    AP_ARGS+=($TF_APPLY_FLAGS)
  elif [[ "${CI:-false}" == "true" || "${TF_APPLY_AUTO:-0}" == "1" ]]; then
    AP_ARGS+=(-auto-approve)
  fi
  log "terraform apply ${AP_ARGS[*]}"
  (cd "$TF_DIR" && terraform "${AP_ARGS[@]}")
else
  log "Skipping terraform (--skip-terraform)"
fi

# Default: kustomize uses docker.io/xoibsurferx/devops-challenge:latest from Docker Hub. Opt-in: build a tag in-repo and you must
# kustomize edit the overlay to that tag, or use a separate image override — here we only build/load a tag (default :local) for advanced use.
if [[ "$BUILD_LOCAL_IMAGE" == "true" ]]; then
  log "Local image build: $IMAGE_NAME (override the local overlay to use this tag if you want the deployment to use it)"
  MK_DRIVER="${MINIKUBE_DRIVER:-$(minikube -p "$MINIKUBE_PROFILE" config get driver 2>/dev/null || true)}"
  if [[ "$MK_DRIVER" == "docker" ]]; then
    command -v docker &>/dev/null || { log "docker CLI is required for minikube with --driver=docker"; exit 1; }
    (cd "$ROOT_DIR" && docker build -t "$IMAGE_NAME" -f Dockerfile .)
  elif command -v docker &>/dev/null; then
    if eval "$(minikube -p "$MINIKUBE_PROFILE" docker-env)"; then
      (cd "$ROOT_DIR" && docker build -t "$IMAGE_NAME" -f Dockerfile .)
    else
      log "minikube docker-env not available; host docker build + minikube image load: $IMAGE_NAME (driver=${MK_DRIVER:-?})"
      docker build -t "$IMAGE_NAME" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR"
      minikube -p "$MINIKUBE_PROFILE" image load --daemon --overwrite "$IMAGE_NAME"
    fi
  else
    log "minikube image build (no docker CLI; relative context): $IMAGE_NAME"
    (cd "$ROOT_DIR" && minikube -p "$MINIKUBE_PROFILE" image build -t "$IMAGE_NAME" -f Dockerfile .)
  fi
else
  log "App image: docker.io/xoibsurferx/devops-challenge:latest (Docker Hub; not building locally). Ensure the cluster can reach registry-1.docker.io if running a fresh node."
fi

if [[ "$SKIP_KUSTOMIZE" != "true" ]]; then
  log "kubectl apply: $KUSTOMIZE_APP_DIR"
  kubectl apply -k "$KUSTOMIZE_APP_DIR"
  log "Waiting for postgres and nextjs"
  kubectl -n devops-challenge rollout status deployment/postgres --timeout=180s
  kubectl -n devops-challenge rollout status deployment/nextjs --timeout=300s
  IP=$(minikube -p "$MINIKUBE_PROFILE" ip 2>/dev/null || true)
  if [[ -n "${IP:-}" ]]; then
    log "App (NodePort 30080): http://$IP:30080  health: /api/health"
    log "If the browser hangs or never loads (common: minikube + Docker Desktop on macOS), use one of:"
    log "  minikube -p \"$MINIKUBE_PROFILE\" service nextjs -n devops-challenge --url"
    log "  kubectl -n devops-challenge port-forward svc/nextjs 3000:80  # then http://127.0.0.1:3000  and  http://127.0.0.1:3000/api/health"
  fi
  if kubectl get ns argocd &>/dev/null; then
    log "Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 8888:443"
    kubectl -n argocd rollout status deployment/argocd-server --timeout=300s 2>/dev/null || true
    log "Argo initial admin (if secret exists): kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{.data.password|base64decode}}'"
  fi
else
  log "Skipping kustomize apply"
fi

log "Done. tear down: ./scripts/local-down.sh  (or: make local-down)"
