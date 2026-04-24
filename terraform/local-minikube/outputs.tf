output "minikube_profile" {
  value       = var.minikube_profile
  description = "minikube -p to use in later commands and scripts."
}

output "kustomize_apply_app_local" {
  value       = "kubectl apply -k kustomize/app/overlays/local"
  description = "Apply the sample app to the (now configured) default kubeconfig."
}

output "kustomize_apply_argocd_local" {
  value       = "kubectl apply -k kustomize/argocd/overlays/local"
  description = "After editing repoURL in the Application, apply AppProject + Application to register GitOps."
}

output "kustomize_apply_argocd_production" {
  value       = "kubectl apply -k kustomize/argocd/overlays/production"
  description = "Same as local but Application points at kustomize/app/overlays/production."
}

output "port_forward_argocd" {
  value = "kubectl port-forward svc/argocd-server -n argocd 8888:443"
}
