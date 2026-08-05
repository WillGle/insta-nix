{
  # Decorative palette. Wallpaper-driven at runtime: matugen overwrites every
  # value below, so nothing here may carry meaning on its own.
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

  # Signal palette — CONTRACT: these are the only colors allowed to encode a
  # state, a severity level or an indicator line (waybar border-top /
  # border-bottom). They are deliberately kept out of `colors` so the runtime
  # theme generator can never reach them: matugen flattens every semantic role
  # onto Material tone 80, which collapses hue *and* luminance and destroys the
  # warning ladder. See modules/nixos/theme.nix for the uniqueness assertion.
  #
  # Values are chosen to separate on hue AND luminance, because a 2px indicator
  # line carries most of its weight through brightness contrast:
  #   eco 76% > notice 45% > warning 37% ~ ok 36% > muted 34% > critical 26%
  signal = {
    ok = "#3fb950"; # xanh lá  — trạng thái tốt / mức thấp
    notice = "#58a6ff"; # xanh dương — thông tin / mức trung bình
    warning = "#d29922"; # hổ phách — cảnh báo
    critical = "#f85149"; # đỏ — nguy cấp / lỗi
    eco = "#00ffcc"; # xanh ngọc sáng — đang sạc / đang hoạt động
    muted = "#8b949e"; # xám — idle / mất kết nối / tắt tiếng
  };

  fonts = {
    ui = {
      family = "FiraCode Nerd Font";
      size = 13;
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
    source = ./assets/699940446_27093267803673575_2255830419586770226_n.jpg;
    name = "699940446_27093267803673575_2255830419586770226_n.jpg";
  };

  runtime = {
    enable = true;
    cacheDir = ".cache/theme";
  };
}
