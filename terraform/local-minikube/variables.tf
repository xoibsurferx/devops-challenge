variable "minikube_profile" {
  type        = string
  description = "minikube -p value (isolated local cluster name)."
  default     = "minikube"
}

variable "minikube_memory" {
  type        = string
  description = "Memory for the minikube VM / driver (e.g. 8192m)."
  default     = "8192"
}

variable "minikube_cpus" {
  type        = number
  description = "vCPUs for minikube."
  default     = 4
}

variable "minikube_driver" {
  type        = string
  description = "minikube --driver. Use \"docker\" on macOS (Docker Desktop) to avoid a legacy VirtualBox profile. Override e.g. kvm2 on Linux if needed."
  default     = "docker"
}

variable "enable_metrics_server" {
  type        = bool
  description = "Enable metrics-server addon (needed for HPA in the production app overlay)."
  default     = true
}

variable "enable_ingress" {
  type        = bool
  description = "Enable ingress addon (optional for this app, common for demos)."
  default     = true
}

variable "install_argocd" {
  type        = bool
  description = "Install Argo CD into the cluster after minikube is up."
  default     = true
}

variable "argocd_version" {
  type        = string
  description = "Pinned Argo CD release tag (https://github.com/argoproj/argo-cd/releases)."
  default     = "v2.12.0"
}
