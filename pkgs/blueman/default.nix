{ blueman }:

blueman.overrideAttrs (old: {
  # Pairing needs visible Confirm/Deny buttons; keep informational notices in Dunst.
  postPatch = (old.postPatch or "") + ''
    substituteInPlace blueman/main/applet/BluezAgent.py \
      --replace-fail $'self._notification = Notification("Bluetooth", notify_message, 0,\n' \
        $'self._notification = _NotificationDialog("Bluetooth", notify_message, 0,\n'
  '';
  postFixup = (old.postFixup or "") + ''
    rm -f "$out/lib/systemd/user/blueman-applet.service"
    rm -f "$out/etc/xdg/autostart/blueman.desktop"
  '';
})
