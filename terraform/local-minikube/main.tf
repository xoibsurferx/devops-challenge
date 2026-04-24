# Local-only: minikube + addons + optional Argo CD install using the minikube / kubectl CLIs.
# See scripts/local-up.sh and scripts/local-down.sh.

resource "null_resource" "minikube" {
  triggers = {
    profile = var.minikube_profile
    memory  = var.minikube_memory
    cpus    = tostring(var.minikube_cpus)
    driver  = var.minikube_driver
  }

  provisioner "local-exec" {
    environment = {
      MINIKUBE_PROFILE = var.minikube_profile
      MINIKUBE_MEMORY  = var.minikube_memory
      MINIKUBE_CPUS    = tostring(var.minikube_cpus)
      MINIKUBE_DRIVER  = var.minikube_driver
    }
    command = <<-EOT
      set -euf
      if [ -n "$MINIKUBE_DRIVER" ]; then
        minikube -p "$MINIKUBE_PROFILE" start --memory="$MINIKUBE_MEMORY" --cpus="$MINIKUBE_CPUS" --driver="$MINIKUBE_DRIVER"
      else
        minikube -p "$MINIKUBE_PROFILE" start --memory="$MINIKUBE_MEMORY" --cpus="$MINIKUBE_CPUS"
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "minikube -p ${self.triggers.profile} delete || true"
  }
}

resource "null_resource" "minikube_addons" {
  depends_on = [null_resource.minikube]

  triggers = {
    profile         = var.minikube_profile
    metrics_server  = tostring(var.enable_metrics_server)
    ingress         = tostring(var.enable_ingress)
    minikube_serial = null_resource.minikube.id
  }

  provisioner "local-exec" {
    environment = { MINIKUBE_PROFILE = var.minikube_profile }
    command     = <<-EOT
      set -euf
      if [ "${var.enable_metrics_server ? "1" : "0"}" = "1" ]; then
        minikube -p "$MINIKUBE_PROFILE" addons enable metrics-server
      fi
      if [ "${var.enable_ingress ? "1" : "0"}" = "1" ]; then
        minikube -p "$MINIKUBE_PROFILE" addons enable ingress || true
      fi
    EOT
  }
}

resource "null_resource" "argocd" {
  count = var.install_argocd ? 1 : 0

  depends_on = [null_resource.minikube_addons]

  triggers = {
    profile     = var.minikube_profile
    version     = var.argocd_version
    addon_chain = null_resource.minikube_addons.id
  }

  provisioner "local-exec" {
    environment = { MINIKUBE_PROFILE = var.minikube_profile }
    command     = <<-EOT
      set -euf
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
      kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${var.argocd_version}/manifests/install.yaml"
    EOT
  }
}
