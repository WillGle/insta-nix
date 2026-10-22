{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    terraform
    ansible
    docker-compose
    opentofu
    awscli2
    terraform-ls
  ];
}
