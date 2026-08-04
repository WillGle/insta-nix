{ config, pkgs, osConfig, lib, ... }:
let
  inherit (osConfig) theme;
  themeRoot = "${config.xdg.configHome}/theme";
  themeAssetsDir = "${themeRoot}/assets";
  themeGeneratedDir = "${themeRoot}/generated";
  themeTemplatesDir = "${themeRoot}/templates";
  themeStaticEnv = "${themeRoot}/static.env";
  themeApplyPath = "${themeRoot}/theme-apply";
  themeWallpaperPath = "${themeAssetsDir}/${theme.wallpaper.name}";

  # Runtime state lives outside the Home Manager generation so a user-selected
  # wallpaper survives rebuilds and is never a read-only store path.
  themeStateDir = "${config.xdg.stateHome}/theme";
  themeWallpaperStore = "${themeStateDir}/wallpapers";
  themeWallpaperPointer = "${themeStateDir}/wallpaper.path";
  themeLockFile = "${themeStateDir}/theme-apply.lock";

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
  waybarSeed = pkgs.writeText "theme-waybar.css" (renderTheme ../../theme/templates/waybar.css.template);
  rofiSeed = pkgs.writeText "theme-rofi.rasi" (renderTheme ../../theme/templates/rofi.rasi.template);
  hyprlockSeed = pkgs.writeText "theme-hyprlock.conf" (renderTheme ../../theme/templates/hyprlock.conf.template);
  hyprlandSeed =
    pkgs.writeText "theme-hyprland-decoration.conf" (renderTheme ../../theme/templates/hyprland-decoration.conf.template);
  nvimSeed = pkgs.writeText "theme-nvim-matugen.lua" (renderTheme ../../theme/templates/nvim-colors.lua.template);
  hyprpaperSeed = pkgs.writeText "theme-hyprpaper.conf" (renderTheme ../../theme/templates/hyprpaper.conf.template);
  paletteSeed = pkgs.writeText "theme-palette.json" (
    builtins.toJSON {
      source = "static-fallback";
      inherit (theme) colors;
    }
  );
  themeBinReplacements = [
    [ "__BASH_BIN__" "${pkgs.bash}/bin/bash" ]
    [ "__MATUGEN_BIN__" "${pkgs.matugen}/bin/matugen" ]
    [ "__JQ_BIN__" "${pkgs.jq}/bin/jq" ]
    [ "__SED_BIN__" "${pkgs.gnused}/bin/sed" ]
    [ "__GREP_BIN__" "${pkgs.gnugrep}/bin/grep" ]
    [ "__FIND_BIN__" "${pkgs.findutils}/bin/find" ]
    [ "__SORT_BIN__" "${pkgs.coreutils}/bin/sort" ]
    [ "__ROFI_BIN__" "${pkgs.rofi}/bin/rofi" ]
    [ "__MKTEMP_BIN__" "${pkgs.coreutils}/bin/mktemp" ]
    [ "__MKDIR_BIN__" "${pkgs.coreutils}/bin/mkdir" ]
    [ "__MV_BIN__" "${pkgs.coreutils}/bin/mv" ]
    [ "__CP_BIN__" "${pkgs.coreutils}/bin/cp" ]
    [ "__RM_BIN__" "${pkgs.coreutils}/bin/rm" ]
    [ "__CAT_BIN__" "${pkgs.coreutils}/bin/cat" ]
    [ "__OD_BIN__" "${pkgs.coreutils}/bin/od" ]
    [ "__TR_BIN__" "${pkgs.coreutils}/bin/tr" ]
    [ "__SHA256_BIN__" "${pkgs.coreutils}/bin/sha256sum" ]
    [ "__READLINK_BIN__" "${pkgs.coreutils}/bin/readlink" ]
    [ "__TIMEOUT_BIN__" "${pkgs.coreutils}/bin/timeout" ]
    [ "__SLEEP_BIN__" "${pkgs.coreutils}/bin/sleep" ]
    [ "__CMP_BIN__" "${pkgs.diffutils}/bin/cmp" ]
    [ "__FLOCK_BIN__" "${pkgs.util-linux}/bin/flock" ]
    [ "__SYSTEMCTL_BIN__" "${pkgs.systemd}/bin/systemctl" ]
    [ "__LS_BIN__" "${pkgs.coreutils}/bin/ls" ]
    [ "__HEAD_BIN__" "${pkgs.coreutils}/bin/head" ]
    [ "__HYPRCTL_BIN__" "${pkgs.hyprland}/bin/hyprctl" ]
    [ "__THEME_STATIC_ENV__" themeStaticEnv ]
    [ "__THEME_APPLY_BIN__" themeApplyPath ]
  ];

  themeApplyScript = replaceMany themeBinReplacements ../../theme/scripts/theme-apply.sh.template;
  wallpaperScript = replaceMany themeBinReplacements ../../theme/scripts/wallpaper.sh.template;

  themeLockScript = replaceMany (
    commonReplacements
    ++ [
      [ "__HYPRLOCK_BIN__" "${pkgs.hyprlock}/bin/hyprlock" ]
    ]
  ) ../../theme/scripts/theme-lock.sh.template;

in
{
  programs.waybar.systemd.enable = lib.mkForce true;
  wayland.systemd.target = "hyprland-session.target";


  xdg.configFile = {
    "theme/templates".source = ../../theme/templates;
    "theme/assets/${theme.wallpaper.name}".source = theme.wallpaper.source;
    "theme/static.env".text = ''
      THEME_GENERATOR_VERSION=${lib.escapeShellArg "v4"}
      THEME_RUNTIME_ENABLE=${if theme.runtime.enable then "1" else "0"}
      THEME_TEMPLATE_DIR=${lib.escapeShellArg themeTemplatesDir}
      THEME_GENERATED_DIR=${lib.escapeShellArg themeGeneratedDir}
      THEME_STATE_DIR=${lib.escapeShellArg themeStateDir}
      THEME_WALLPAPER_STORE=${lib.escapeShellArg themeWallpaperStore}
      THEME_WALLPAPER_POINTER=${lib.escapeShellArg themeWallpaperPointer}
      THEME_LOCK_FILE=${lib.escapeShellArg themeLockFile}
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

    "waybar/config.jsonc" = {
      source = ../../assets/common/waybar/config.jsonc;
      onChange = ''
        if ${pkgs.systemd}/bin/systemctl --user is-active --quiet waybar.service; then
          ${pkgs.systemd}/bin/systemctl --user reload waybar.service
        fi
      '';
    };
    "waybar/style.css".text = ''
      @import url("file://${themeGeneratedDir}/waybar.css");
    '';

    "rofi/config.rasi".source = ../../assets/common/rofi/config.rasi;
    "rofi/theme.rasi".source = generatedLink "rofi.rasi";


    "nvim/colors/matugen.lua".source = generatedLink "nvim-matugen.lua";
    "nvim/plugin/matugen.lua".text = ''
      vim.opt.termguicolors = true
      pcall(vim.cmd.colorscheme, "matugen")
    '';

    "hypr/hyprpaper.conf".source = generatedLink "hyprpaper.conf";
  };

  home = {
    file = {
      ".local/bin/theme-lock" = {
        text = themeLockScript;
        executable = true;
      };
      ".local/bin/rofi-show" = {
        source = ../../assets/common/rofi/rofi-show;
        executable = true;
      };
      ".local/bin/rofi-clipboard" = {
        source = ../../assets/common/rofi/rofi-clipboard;
        executable = true;
      };
      ".local/bin/wallpaper" = {
        text = wallpaperScript;
        executable = true;
      };
    };

    activation = {
      themeGeneratedSeed = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "linkGeneration" ] ''
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
        if [ ! -e "${themeGeneratedDir}/hyprpaper.conf" ]; then
          ${pkgs.coreutils}/bin/cp "${hyprpaperSeed}" "${themeGeneratedDir}/hyprpaper.conf"
        fi
        if [ ! -e "${themeGeneratedDir}/palette.json" ]; then
          ${pkgs.coreutils}/bin/cp "${paletteSeed}" "${themeGeneratedDir}/palette.json"
        fi
      '';

      # Runs after the seed has populated the generated directory and after
      # reloadSystemd, so a reload can never race the generation it triggers.
      themeApplyTrigger = lib.mkIf theme.runtime.enable (
        lib.hm.dag.entryAfter [ "themeGeneratedSeed" "reloadSystemd" ] ''
          # theme-apply stages every output and only commits once the whole
          # generation succeeded, so a failure here leaves the previously
          # generated theme intact. Let it surface instead of swallowing it:
          # a silent warning would hide a broken theme behind a green rebuild.
          run ${pkgs.bash}/bin/bash ${themeApplyPath}
        ''
      );
    };
  };

  systemd.user = {
    services = {
      waybar = {
        Unit.PartOf = lib.mkForce [ "hyprland-session.target" ];
        Install.WantedBy = lib.mkForce [ "hyprland-session.target" ];
      };

      theme-apply = lib.mkIf theme.runtime.enable {
        Unit = {
          Description = "Generate runtime theme palette for core Wayland surfaces";
        };
        Service = {
          Type = "oneshot";
          # Absolute interpreter: the unit starts with an empty PATH, so a
          # `/usr/bin/env bash` shebang would fail before the script runs.
          ExecStart = "${pkgs.bash}/bin/bash ${themeApplyPath}";
          TimeoutStartSec = "120s";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };

      polkit-agent = {
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
    };
  };
}
