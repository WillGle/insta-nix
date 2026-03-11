{ lib, ... }:
{
  # Canary DNS profile:
  # Keep current resolver policy, but test DoT in opportunistic mode first.
  services.resolved.dnsovertls = lib.mkForce "opportunistic";
}
