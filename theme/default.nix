{
  # Matugen replaces decorative colors for desktop/session surfaces.
  # Terminal and shell consumers use these values statically.
  colors = {
    base = "#0d1117";
    mantle = "#161b22";
    text = "#f0f6fc";
    subtext = "#8b949e";
    accent = "#58a6ff";
    success = "#3fb950";
    warning = "#d29922";
    error = "#f85149";
    purple = "#bc8cff";
    cyan = "#39c5cf";
  };

  # Only signal colors encode states, severity, and indicator lines.
  # Keep them outside colors: Matugen collapses hues and brightness,
  # erasing severity differences. Distinct hues and brightness keep thin
  # indicators readable; modules/nixos/desktop/theme.nix checks uniqueness.
  signal = {
    ok = "#3fb950"; # xanh lá  — trạng thái tốt / mức thấp
    notice = "#58a6ff"; # xanh dương — thông tin / mức trung bình
    warning = "#d29922"; # hổ phách — cảnh báo
    critical = "#f85149"; # đỏ — nguy cấp / lỗi
    eco = "#00ffcc"; # xanh ngọc sáng — đang sạc / đang hoạt động
    muted = "#8b949e"; # xám — idle / mất kết nối / tắt tiếng
  };

  fonts = {
    # Waybar renders this as CSS `font-size: <n>px`.
    ui = {
      family = "FiraCode Nerd Font";
      size = 13;
    };

    # Rofi uses Pango points; ui.size is in pixels.
    rofi = {
      size = 10;
    };

    mono = {
      family = "JetBrainsMono Nerd Font";
      size = 11;
    };

    lock = {
      family = "Inter";
      boldFamily = "Inter Bold";
      clockSize = 120;
      textSize = 25;
    };
  };

  cursor = {
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  wallpaper = {
    # Keep personal wallpapers in XDG state; hosts may provide a packaged fallback.
    source = null;
  };

  runtime = {
    enable = true;
  };
}
