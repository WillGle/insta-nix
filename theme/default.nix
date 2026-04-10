{
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
    source = ./assets/wallpaper.png;
    name = "wallpaper.png";
  };

  runtime = {
    enable = true;
    cacheDir = ".cache/theme";
  };
}
