_: {
  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/86292ded-a2fe-4f4c-bd5a-ab9afdb1e369";
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
