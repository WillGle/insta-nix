_: {
  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/GENERIC_VAULT_UUID";
    fsType = "ext4";
    options = [
      "defaults"
      "noatime"
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.idle-timeout=60"
    ];
  };
}
