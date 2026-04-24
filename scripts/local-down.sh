#!/usr/bin/env bash
# Destroy the local minikube environment managed by terraform/local-minikube.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-"$ROOT_DIR/terraform/local-minikube"}"

if ! command -v terraform >/dev/null; then
  echo "terraform is required." >&2
  exit 1
fi

export TF_IN_AUTOMATION="${TF_IN_AUTOMATION:-0}"
FLAGS=(-input=false)
if [[ "${1:-}" == "-auto-approve" || "${CI:-false}" == "true" || "${TF_DESTROY_AUTO:-0}" == "1" ]]; then
  FLAGS+=(-auto-approve)
fi

echo "terraform destroy: $TF_DIR  (add -auto-approve: ./scripts/local-down.sh -auto-approve or CI=1)"
(cd "$TF_DIR" && terraform init -input=false && terraform destroy "${FLAGS[@]}")
