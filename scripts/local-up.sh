#!/usr/bin/env bash
# Terraform bring-up (minikube + addons + Argo CD), then build the app image and apply Kustomize (local app overlay).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-"$ROOT_DIR/terraform/local-minikube"}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
IMAGE_NAME="${IMAGE_NAME:-docker.io/xoibsurferx/devops-challenge:local}"
KUSTOMIZE_APP_DIR="${KUSTOMIZE_APP_DIR:-"$ROOT_DIR/kustomize/app/overlays/local"}"
SKIP_TERRAFORM="${SKIP_TERRAFORM:-false}"
SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_KUSTOMIZE="${SKIP_KUSTOMIZE:-false}"

log() { printf '==> %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-terraform) SKIP_TERRAFORM=true; shift ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    --skip-kustomize) SKIP_KUSTOMIZE=true; shift ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "  --skip-terraform  Assume cluster already exists; skip terraform apply"
      echo "  --skip-build     Skip minikube image build (image must exist on the node)"
      echo "  --skip-kustomize  Skip kubectl apply -k (only terraform + build)"
      echo "  Env: TF_DIR, MINIKUBE_PROFILE, IMAGE_NAME, KUSTOMIZE_APP_DIR"
      exit 0
      ;;
    *) log "Unknown option: $1"; exit 1 ;;
  esac
done

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

if [[ "$SKIP_BUILD" != "true" ]]; then
  log "minikube image build: $IMAGE_NAME"
  minikube -p "$MINIKUBE_PROFILE" image build -t "$IMAGE_NAME" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR"
else
  log "Skipping image build (ensure the cluster can resolve $IMAGE_NAME; use minikube image load or build)"
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
