{ config, pkgs, osConfig, lib, ... }:
let
  theme = osConfig.theme;
  themeRoot = "${config.xdg.configHome}/theme";
  themeAssetsDir = "${themeRoot}/assets";
  themeGeneratedDir = "${themeRoot}/generated";
  themeTemplatesDir = "${themeRoot}/templates";
  themeStaticEnv = "${themeRoot}/static.env";
  themeApplyPath = "${themeRoot}/theme-apply";
  themeWallpaperPath = "${themeAssetsDir}/${theme.wallpaper.name}";
  generatedLink = path: config.lib.file.mkOutOfStoreSymlink "${themeGeneratedDir}/${path}";

  strip = color: lib.removePrefix "#" color;
  replaceMany =
    replacements: file:
    let
      keys = map (entry: builtins.elemAt entry 0) replacements;
      values = map (entry: builtins.elemAt entry 1) replacements;
    in
    builtins.replaceStrings keys values (builtins.readFile file);

  commonReplacements = [
    [ "__BASE__" theme.colors.base ]
    [ "__MANTLE__" theme.colors.mantle ]
    [ "__TEXT__" theme.colors.text ]
    [ "__SUBTEXT__" theme.colors.subtext ]
    [ "__ACCENT__" theme.colors.accent ]
    [ "__SUCCESS__" theme.colors.success ]
    [ "__WARNING__" theme.colors.warning ]
    [ "__ERROR__" theme.colors.error ]
    [ "__PURPLE__" theme.colors.purple ]
    [ "__CYAN__" theme.colors.cyan ]
    [ "__BASE_STRIP__" (strip theme.colors.base) ]
    [ "__MANTLE_STRIP__" (strip theme.colors.mantle) ]
    [ "__TEXT_STRIP__" (strip theme.colors.text) ]
    [ "__SUBTEXT_STRIP__" (strip theme.colors.subtext) ]
    [ "__ACCENT_STRIP__" (strip theme.colors.accent) ]
    [ "__SUCCESS_STRIP__" (strip theme.colors.success) ]
    [ "__WARNING_STRIP__" (strip theme.colors.warning) ]
    [ "__ERROR_STRIP__" (strip theme.colors.error) ]
    [ "__PURPLE_STRIP__" (strip theme.colors.purple) ]
    [ "__CYAN_STRIP__" (strip theme.colors.cyan) ]
    [ "__UI_FONT__" theme.fonts.ui.family ]
    [ "__UI_FONT_SIZE__" (toString theme.fonts.ui.size) ]
    [ "__MONO_FONT__" theme.fonts.mono.family ]
    [ "__MONO_FONT_SIZE__" (toString theme.fonts.mono.size) ]
    [ "__LOCK_FONT__" theme.fonts.lock.family ]
    [ "__LOCK_FONT_BOLD__" theme.fonts.lock.boldFamily ]
    [ "__LOCK_CLOCK_SIZE__" (toString theme.fonts.lock.clockSize) ]
    [ "__LOCK_TEXT_SIZE__" (toString theme.fonts.lock.textSize) ]
    [ "__CURSOR_NAME__" theme.cursor.name ]
    [ "__CURSOR_SIZE__" (toString theme.cursor.size) ]
    [ "__WALLPAPER_PATH__" themeWallpaperPath ]
    [ "__THEME_GENERATED_DIR__" themeGeneratedDir ]
  ];

  renderTheme = file: replaceMany commonReplacements file;
  waybarSeed = pkgs.writeText "theme-waybar.css" (renderTheme ../theme/templates/waybar.css.template);
  rofiSeed = pkgs.writeText "theme-rofi.rasi" (renderTheme ../theme/templates/rofi.rasi.template);
  hyprlockSeed = pkgs.writeText "theme-hyprlock.conf" (renderTheme ../theme/templates/hyprlock.conf.template);
  hyprlandSeed =
    pkgs.writeText "theme-hyprland-decoration.conf" (renderTheme ../theme/templates/hyprland-decoration.conf.template);
  nvimSeed = pkgs.writeText "theme-nvim-matugen.lua" (renderTheme ../theme/templates/nvim-colors.lua.template);
  paletteSeed = pkgs.writeText "theme-palette.json" (
    builtins.toJSON {
      source = "static-fallback";
      colors = theme.colors;
    }
  );
  themeApplyScript = replaceMany [
    [ "__MATUGEN_BIN__" "${pkgs.matugen}/bin/matugen" ]
    [ "__JQ_BIN__" "${pkgs.jq}/bin/jq" ]
    [ "__SED_BIN__" "${pkgs.gnused}/bin/sed" ]
    [ "__MKTEMP_BIN__" "${pkgs.coreutils}/bin/mktemp" ]
    [ "__MKDIR_BIN__" "${pkgs.coreutils}/bin/mkdir" ]
    [ "__MV_BIN__" "${pkgs.coreutils}/bin/mv" ]
    [ "__RM_BIN__" "${pkgs.coreutils}/bin/rm" ]
    [ "__CMP_BIN__" "${pkgs.diffutils}/bin/cmp" ]
    [ "__LS_BIN__" "${pkgs.coreutils}/bin/ls" ]
    [ "__HEAD_BIN__" "${pkgs.coreutils}/bin/head" ]
    [ "__NOHUP_BIN__" "${pkgs.coreutils}/bin/nohup" ]
    [ "__PKILL_BIN__" "${pkgs.procps}/bin/pkill" ]
    [ "__PGREP_BIN__" "${pkgs.procps}/bin/pgrep" ]
    [ "__WAYBAR_BIN__" "${pkgs.waybar}/bin/waybar" ]
    [ "__HYPRCTL_BIN__" "${pkgs.hyprland}/bin/hyprctl" ]
    [ "__THEME_STATIC_ENV__" themeStaticEnv ]
  ] ../theme/scripts/theme-apply.sh.template;

  themeLockScript = replaceMany (
    commonReplacements
    ++ [
      [ "__HYPRLOCK_BIN__" "${pkgs.hyprlock}/bin/hyprlock" ]
    ]
  ) ../theme/scripts/theme-lock.sh.template;
in
{
  wayland.systemd.target = "default.target";


  xdg.configFile = {
    "theme/templates".source = ../theme/templates;
    "theme/assets/${theme.wallpaper.name}".source = theme.wallpaper.source;
    "theme/static.env".text = ''
      THEME_GENERATOR_VERSION=${lib.escapeShellArg "v3"}
      THEME_RUNTIME_ENABLE=${if theme.runtime.enable then "1" else "0"}
      THEME_TEMPLATE_DIR=${lib.escapeShellArg themeTemplatesDir}
      THEME_GENERATED_DIR=${lib.escapeShellArg themeGeneratedDir}
      THEME_WALLPAPER=${lib.escapeShellArg themeWallpaperPath}
      THEME_UI_FONT=${lib.escapeShellArg theme.fonts.ui.family}
      THEME_UI_FONT_SIZE=${lib.escapeShellArg (toString theme.fonts.ui.size)}
      THEME_MONO_FONT=${lib.escapeShellArg theme.fonts.mono.family}
      THEME_MONO_FONT_SIZE=${lib.escapeShellArg (toString theme.fonts.mono.size)}
      THEME_LOCK_FONT=${lib.escapeShellArg theme.fonts.lock.family}
      THEME_LOCK_FONT_BOLD=${lib.escapeShellArg theme.fonts.lock.boldFamily}
      THEME_LOCK_CLOCK_SIZE=${lib.escapeShellArg (toString theme.fonts.lock.clockSize)}
      THEME_LOCK_TEXT_SIZE=${lib.escapeShellArg (toString theme.fonts.lock.textSize)}
      THEME_STATIC_BASE=${lib.escapeShellArg theme.colors.base}
      THEME_STATIC_MANTLE=${lib.escapeShellArg theme.colors.mantle}
      THEME_STATIC_TEXT=${lib.escapeShellArg theme.colors.text}
      THEME_STATIC_SUBTEXT=${lib.escapeShellArg theme.colors.subtext}
      THEME_STATIC_ACCENT=${lib.escapeShellArg theme.colors.accent}
      THEME_STATIC_SUCCESS=${lib.escapeShellArg theme.colors.success}
      THEME_STATIC_WARNING=${lib.escapeShellArg theme.colors.warning}
      THEME_STATIC_ERROR=${lib.escapeShellArg theme.colors.error}
      THEME_STATIC_PURPLE=${lib.escapeShellArg theme.colors.purple}
      THEME_STATIC_CYAN=${lib.escapeShellArg theme.colors.cyan}
    '';
    "theme/theme-apply" = {
      text = themeApplyScript;
      executable = true;
    };

    "waybar/config.jsonc".source = ../dotfiles/common/waybar/config.jsonc;
    "waybar/style.css".text = ''
      @import url("file://${themeGeneratedDir}/waybar.css");
    '';
    "waybar/cliphist.sh" = {
      source = ../dotfiles/common/waybar/cliphist.sh;
      executable = true;
    };

    "rofi/config.rasi".source = ../dotfiles/common/rofi/config.rasi;
    "rofi/theme.rasi".source = generatedLink "rofi.rasi";


    "nvim/colors/matugen.lua".source = generatedLink "nvim-matugen.lua";
    "nvim/plugin/matugen.lua".text = ''
      vim.opt.termguicolors = true
      pcall(vim.cmd.colorscheme, "matugen")
    '';

    "hypr/hyprpaper.conf".text = renderTheme ../theme/templates/hyprpaper.conf.template;
  };

  home.file = {
    ".local/bin/theme-lock" = {
      text = themeLockScript;
      executable = true;
    };
    ".local/bin/rofi-show" = {
      source = ../dotfiles/common/rofi/rofi-show.sh;
      executable = true;
    };
    ".local/bin/rofi-clipboard" = {
      source = ../dotfiles/common/rofi/rofi-clipboard.sh;
      executable = true;
    };
  };

  home.activation.themeGeneratedSeed = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "linkGeneration" ] ''
    mkdir -p "${themeGeneratedDir}"
    if [ ! -e "${themeGeneratedDir}/waybar.css" ]; then
      ${pkgs.coreutils}/bin/cp "${waybarSeed}" "${themeGeneratedDir}/waybar.css"
    fi
    if [ ! -e "${themeGeneratedDir}/rofi.rasi" ]; then
      ${pkgs.coreutils}/bin/cp "${rofiSeed}" "${themeGeneratedDir}/rofi.rasi"
    fi
    if [ ! -e "${themeGeneratedDir}/hyprlock.conf" ]; then
      ${pkgs.coreutils}/bin/cp "${hyprlockSeed}" "${themeGeneratedDir}/hyprlock.conf"
    fi
    if [ ! -e "${themeGeneratedDir}/hyprland-decoration.conf" ]; then
      ${pkgs.coreutils}/bin/cp "${hyprlandSeed}" "${themeGeneratedDir}/hyprland-decoration.conf"
    fi
    if [ ! -e "${themeGeneratedDir}/nvim-matugen.lua" ]; then
      ${pkgs.coreutils}/bin/cp "${nvimSeed}" "${themeGeneratedDir}/nvim-matugen.lua"
    fi
    if [ ! -e "${themeGeneratedDir}/palette.json" ]; then
      ${pkgs.coreutils}/bin/cp "${paletteSeed}" "${themeGeneratedDir}/palette.json"
    fi
  '';

  home.activation.themeApplyTrigger = lib.mkIf theme.runtime.enable (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${themeApplyPath} || true
  '');

  systemd.user.services.theme-apply = lib.mkIf theme.runtime.enable {
    Unit = {
      Description = "Generate runtime theme palette for core Wayland surfaces";
    };
    Service = {
      Type = "oneshot";
      ExecStart = themeApplyPath;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.paths.theme-apply = lib.mkIf theme.runtime.enable {
    Unit = {
      Description = "Watch wallpaper asset and re-apply the runtime theme";
    };
    Path = {
      PathChanged = themeWallpaperPath;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "Polkit Authentication Agent";
      StartLimitBurst = 3;
      StartLimitIntervalSec = "30s";
    };
    Service = {
      ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
      Restart = "on-failure";
      RestartSec = "3s";
      RestartPreventExitStatus = [ "SIGABRT" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
