{ blueman }:

blueman.overrideAttrs (old: {
  postFixup = (old.postFixup or "") + ''
    rm -f "$out/lib/systemd/user/blueman-applet.service"
    rm -f "$out/etc/xdg/autostart/blueman.desktop"
  '';
})
