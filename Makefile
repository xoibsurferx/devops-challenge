# Local minikube (Terraform) + app image + Kustomize. See DEVELOPMENT.md.
.PHONY: local-up local-down kustomize-build image-build

# Full bring-up: terraform in terraform/local-minikube, build image, kubectl apply
local-up:
	@./scripts/local-up.sh

# Tear down: terraform destroy (add -auto-approve or export TF_DESTROY_AUTO=1 for non-interactive)
local-down:
	@./scripts/local-down.sh

# Backwards alias
local-demo: local-up

# Validate kustomize overlays (app + Argo CD) without a cluster
kustomize-build:
	@for d in kustomize/app/overlays/local kustomize/app/overlays/production kustomize/argocd/overlays/local kustomize/argocd/overlays/production; do \
	  echo "kustomize build $$d"; \
	  kubectl kustomize "$$d" >/dev/null 2>&1 || kustomize build "$$d" >/dev/null; \
	done
	@echo "ok"

# Build the production image with local Docker (not minikube)
image-build:
	docker build -t docker.io/xoibsurferx/devops-challenge:local .
