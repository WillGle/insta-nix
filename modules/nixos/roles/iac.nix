{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    ansible
    docker-compose
    opentofu
    awscli2
    terraform-ls # Language server for VSCode support
  ];
}
