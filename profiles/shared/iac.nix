{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    ansible
    terraform # Or 'opentofu' if you prefer the open-source fork
    terraform-ls # Language server for VSCode support
  ];
}
