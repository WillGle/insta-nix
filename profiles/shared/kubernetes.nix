{ pkgs, ... }:

{
  # Enable K3s service
  services.k3s = {
    enable = true;
    role = "server";
    # Extra flags for k3s
    extraFlags = "--disable traefik --disable servicelb"; # We can add these back or use better alternatives later
  };

  # System packages for Kubernetes
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    k9s
  ];

  # Allow the user to access the k3s config without sudo
  # Note: K3s stores config at /etc/rancher/k3s/k3s.yaml by default.
  # We'll set the environment variable.
  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };
  
  # Ensure the config exists and is readable by the 'will' user group (or just set permissions)
  # A common NixOS pattern for K3s local dev:
  # systemd.services.k3s.after = [ "network.target" ];
}
