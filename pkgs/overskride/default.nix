{ overskride }:

overskride.overrideAttrs (old: {
  # Upstream 0.6.6 connects twice after pairing and leaves trust unchanged.
  # Remove when upstream saves trust on explicit connect and connects only once.
  postPatch = (old.postPatch or "") + ''
    # Connect once, after pairing and saving consent for the selected device.
    substituteInPlace src/bluetooth/device.rs \
      --replace-fail $'device.connect().await?;\n        device.connect().await?;' \
        'device.connect().await?;' \
      --replace-fail 'device.connect().await?;' \
        $'device.set_trusted(true).await?;\n        device.connect().await?;'
  '';
})
