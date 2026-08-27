{ pkgs, ... }:

{
  # Kubernetes client tools for the remote lab; its K3s server runs elsewhere.
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    k9s
  ];
}
