{ config, pkgs, osConfig, lib, ... }:
let
  theme = osConfig.theme;
  themeRoot = "${config.xdg.configHome}/theme";
  themeAssetsDir = "${themeRoot}/assets";
  themeFallbackDir = "${themeRoot}/fallback";
  themeRuntimeDir = "${themeRoot}/runtime";
  themeTemplatesDir = "${themeRoot}/templates";
  themeStaticEnv = "${themeRoot}/static.env";
  themeApplyPath = "${themeRoot}/theme-apply";
  themeWallpaperPath = "${themeAssetsDir}/${theme.wallpaper.name}";
  themeCacheDir = "${config.home.homeDirectory}/${theme.runtime.cacheDir}";
  runtimeLink = path: config.lib.file.mkOutOfStoreSymlink "${themeRuntimeDir}/${path}";

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
    [ "__THEME_FALLBACK_DIR__" themeFallbackDir ]
    [ "__THEME_RUNTIME_DIR__" themeRuntimeDir ]
  ];

  renderTheme = file: replaceMany commonReplacements file;
  themeApplyScript = replaceMany [
    [ "__MATUGEN_BIN__" "${pkgs.matugen}/bin/matugen" ]
    [ "__JQ_BIN__" "${pkgs.jq}/bin/jq" ]
    [ "__SED_BIN__" "${pkgs.gnused}/bin/sed" ]
    [ "__AWK_BIN__" "${pkgs.gawk}/bin/awk" ]
    [ "__MKTEMP_BIN__" "${pkgs.coreutils}/bin/mktemp" ]
    [ "__SHA256SUM_BIN__" "${pkgs.coreutils}/bin/sha256sum" ]
    [ "__MKDIR_BIN__" "${pkgs.coreutils}/bin/mkdir" ]
    [ "__MV_BIN__" "${pkgs.coreutils}/bin/mv" ]
    [ "__RM_BIN__" "${pkgs.coreutils}/bin/rm" ]
    [ "__CMP_BIN__" "${pkgs.diffutils}/bin/cmp" ]
    [ "__CAT_BIN__" "${pkgs.coreutils}/bin/cat" ]
    [ "__LS_BIN__" "${pkgs.coreutils}/bin/ls" ]
    [ "__HEAD_BIN__" "${pkgs.coreutils}/bin/head" ]
    [ "__NOHUP_BIN__" "${pkgs.coreutils}/bin/nohup" ]
    [ "__PKILL_BIN__" "${pkgs.procps}/bin/pkill" ]
    [ "__PGREP_BIN__" "${pkgs.procps}/bin/pgrep" ]
    [ "__WAYBAR_BIN__" "${pkgs.waybar}/bin/waybar" ]
    [ "__HYPRCTL_BIN__" "${pkgs.hyprland}/bin/hyprctl" ]
    [ "__FIND_BIN__" "${pkgs.findutils}/bin/find" ]
    [ "__SORT_BIN__" "${pkgs.coreutils}/bin/sort" ]
    [ "__XARGS_BIN__" "${pkgs.findutils}/bin/xargs" ]
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
    "theme/fallback/waybar.css".text = renderTheme ../theme/templates/waybar.css.template;
    "theme/fallback/rofi.rasi".text = renderTheme ../theme/templates/rofi.rasi.template;
    "theme/fallback/hyprlock.conf".text = renderTheme ../theme/templates/hyprlock.conf.template;
    "theme/fallback/hyprland-decoration.conf".text = renderTheme ../theme/templates/hyprland-decoration.conf.template;
    "theme/fallback/nvim-matugen.lua".text = renderTheme ../theme/templates/nvim-colors.lua.template;
    "theme/static.env".text = ''
      THEME_GENERATOR_VERSION=${lib.escapeShellArg "v3"}
      THEME_RUNTIME_ENABLE=${if theme.runtime.enable then "1" else "0"}
      THEME_CACHE_DIR=${lib.escapeShellArg themeCacheDir}
      THEME_TEMPLATE_DIR=${lib.escapeShellArg themeTemplatesDir}
      THEME_RUNTIME_DIR=${lib.escapeShellArg themeRuntimeDir}
      THEME_WALLPAPER=${lib.escapeShellArg themeWallpaperPath}
      THEME_UI_FONT=${lib.escapeShellArg theme.fonts.ui.family}
      THEME_UI_FONT_SIZE=${lib.escapeShellArg (toString theme.fonts.ui.size)}
      THEME_MONO_FONT=${lib.escapeShellArg theme.fonts.mono.family}
      THEME_MONO_FONT_SIZE=${lib.escapeShellArg (toString theme.fonts.mono.size)}
      THEME_LOCK_FONT=${lib.escapeShellArg theme.fonts.lock.family}
      THEME_LOCK_FONT_BOLD=${lib.escapeShellArg theme.fonts.lock.boldFamily}
      THEME_LOCK_CLOCK_SIZE=${lib.escapeShellArg (toString theme.fonts.lock.clockSize)}
      THEME_LOCK_TEXT_SIZE=${lib.escapeShellArg (toString theme.fonts.lock.textSize)}
    '';
    "theme/theme-apply" = {
      text = themeApplyScript;
      executable = true;
    };

    "waybar/config.jsonc".source = ../dotfiles/common/waybar/config.jsonc;
    "waybar/style.css".text = ''
      @import url("file://${themeFallbackDir}/waybar.css");
      @import url("file://${themeRuntimeDir}/waybar.css");
    '';
    "waybar/cliphist.sh" = {
      source = ../dotfiles/common/waybar/cliphist.sh;
      executable = true;
    };

    "rofi/config.rasi".source = ../dotfiles/common/rofi/config.rasi;
    "rofi/theme.rasi".source = runtimeLink "rofi.rasi";


    "nvim/colors/matugen.lua".source = runtimeLink "nvim-matugen.lua";
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

  home.activation.themeRuntimeSeed = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "linkGeneration" ] ''
    mkdir -p "${themeCacheDir}" "${themeRuntimeDir}"
    for file in waybar.css rofi.rasi hyprlock.conf hyprland-decoration.conf nvim-matugen.lua; do
      if [ ! -e "${themeRuntimeDir}/$file" ]; then
        ${pkgs.coreutils}/bin/cp "${themeFallbackDir}/$file" "${themeRuntimeDir}/$file"
      fi
    done
    if [ ! -e "${themeCacheDir}/palette.json" ]; then
      : > "${themeCacheDir}/palette.json"
    fi
    if [ ! -e "${themeCacheDir}/state.sha256" ]; then
      : > "${themeCacheDir}/state.sha256"
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
