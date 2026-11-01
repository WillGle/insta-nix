{
  config,
  pkgs,
  osConfig,
  lib,
  ...
}:
let
  inherit (osConfig) theme;
  inherit (osConfig.theme) signal;
  themeRoot = "${config.xdg.configHome}/theme";
  # Keep personal wallpapers outside Home Manager-managed paths.
  wallpaperDropDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
  themeGeneratedDir = "${themeRoot}/generated";
  themeTemplatesDir = "${themeRoot}/templates";
  themeStaticEnv = "${themeRoot}/static.env";
  themeApplyPath = "${themeRoot}/theme-apply";
  wallpaperPath = "${config.home.homeDirectory}/.local/bin/wallpaper";
  # Resolve user wallpapers from XDG state; hosts may provide a store fallback.
  themeWallpaperPath = lib.optionalString (theme.wallpaper.source != null) (
    toString theme.wallpaper.source
  );

  # Keep wallpaper state outside Home Manager generations so it survives rebuilds.
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

  # Authoritative token values. Templates consume `commonTokenValues`; runtime
  # scripts consume `binTokenValues`. Keep one value per token here.
  commonTokenValues = {
    BASE = theme.colors.base;
    MANTLE = theme.colors.mantle;
    TEXT = theme.colors.text;
    SUBTEXT = theme.colors.subtext;
    ACCENT = theme.colors.accent;
    SUCCESS = theme.colors.success;
    WARNING = theme.colors.warning;
    ERROR = theme.colors.error;
    PURPLE = theme.colors.purple;
    CYAN = theme.colors.cyan;
    BASE_STRIP = strip theme.colors.base;
    MANTLE_STRIP = strip theme.colors.mantle;
    TEXT_STRIP = strip theme.colors.text;
    ACCENT_STRIP = strip theme.colors.accent;
    PURPLE_STRIP = strip theme.colors.purple;
    # Keep signal colors separate from runtime-generated decorative colors.
    SIGNAL_OK = signal.ok;
    SIGNAL_NOTICE = signal.notice;
    SIGNAL_WARNING = signal.warning;
    SIGNAL_CRITICAL = signal.critical;
    SIGNAL_ECO = signal.eco;
    SIGNAL_MUTED = signal.muted;
    UI_FONT = theme.fonts.ui.family;
    UI_FONT_SIZE = toString theme.fonts.ui.size;
    ROFI_FONT_SIZE = toString theme.fonts.rofi.size;
    ROFI_FONT_LABEL_SIZE = toString (theme.fonts.rofi.size + 1);
    ROFI_FONT_SUBTITLE_SIZE = toString (theme.fonts.rofi.size + 2);
    ROFI_FONT_CALENDAR_SIZE = toString (theme.fonts.rofi.size + 4);
    ROFI_FONT_VALUE_SIZE = toString (theme.fonts.rofi.size + 8);
    ROFI_FONT_TITLE_SIZE = toString (theme.fonts.rofi.size + 10);
    MONO_FONT = theme.fonts.mono.family;
    LOCK_FONT = theme.fonts.lock.family;
    LOCK_FONT_BOLD = theme.fonts.lock.boldFamily;
    LOCK_CLOCK_SIZE = toString theme.fonts.lock.clockSize;
    LOCK_TEXT_SIZE = toString theme.fonts.lock.textSize;
    CURSOR_NAME = theme.cursor.name;
    CURSOR_SIZE = toString theme.cursor.size;
    WALLPAPER_PATH = themeWallpaperPath;
    THEME_GENERATED_DIR = themeGeneratedDir;
  };

  binTokenValues = {
    BASH_BIN = "${pkgs.bash}/bin/bash";
    MATUGEN_BIN = "${pkgs.matugen}/bin/matugen";
    JQ_BIN = "${pkgs.jq}/bin/jq";
    SED_BIN = "${pkgs.gnused}/bin/sed";
    GREP_BIN = "${pkgs.gnugrep}/bin/grep";
    FIND_BIN = "${pkgs.findutils}/bin/find";
    SORT_BIN = "${pkgs.coreutils}/bin/sort";
    # Use session rofi for its configured plugins.
    ROFI_BIN = "rofi";
    MKTEMP_BIN = "${pkgs.coreutils}/bin/mktemp";
    MKDIR_BIN = "${pkgs.coreutils}/bin/mkdir";
    MV_BIN = "${pkgs.coreutils}/bin/mv";
    CP_BIN = "${pkgs.coreutils}/bin/cp";
    RM_BIN = "${pkgs.coreutils}/bin/rm";
    CAT_BIN = "${pkgs.coreutils}/bin/cat";
    OD_BIN = "${pkgs.coreutils}/bin/od";
    TR_BIN = "${pkgs.coreutils}/bin/tr";
    SHA256_BIN = "${pkgs.coreutils}/bin/sha256sum";
    READLINK_BIN = "${pkgs.coreutils}/bin/readlink";
    TIMEOUT_BIN = "${pkgs.coreutils}/bin/timeout";
    CMP_BIN = "${pkgs.diffutils}/bin/cmp";
    FLOCK_BIN = "${pkgs.util-linux}/bin/flock";
    SYSTEMCTL_BIN = "${pkgs.systemd}/bin/systemctl";
    LS_BIN = "${pkgs.coreutils}/bin/ls";
    HEAD_BIN = "${pkgs.coreutils}/bin/head";
    HYPRCTL_BIN = "${pkgs.hyprland}/bin/hyprctl";
    HYPRLOCK_BIN = "${pkgs.hyprlock}/bin/hyprlock";
    DUNSTCTL_BIN = "${pkgs.dunst}/bin/dunstctl";
    THEME_STATIC_ENV = themeStaticEnv;
    THEME_APPLY_BIN = themeApplyPath;
    WALLPAPER_BIN = wallpaperPath;
    NOTIFY_SEND_BIN = "${pkgs.libnotify}/bin/notify-send";
    # Share image detection between theme-apply and wallpaper.
    IS_SUPPORTED_IMAGE = builtins.readFile ../../../theme/scripts/lib/is-supported-image.sh;
  };

  placeholder = name: "__${name}__";
  tokenPairs =
    values:
    map (name: [
      (placeholder name)
      values.${name}
    ]) (builtins.attrNames values);
  commonReplacements = tokenPairs commonTokenValues;
  themeBinReplacements = tokenPairs binTokenValues;

  rawTokenValues = commonTokenValues // binTokenValues;
  allPlaceholders = map placeholder (builtins.attrNames rawTokenValues);

  tokensInText =
    text:
    map builtins.head (builtins.filter builtins.isList (builtins.split "(__[A-Z][A-Z0-9_]*__)" text));

  themeSourceFiles =
    lib.filesystem.listFilesRecursive ../../../theme/templates
    ++ lib.filesystem.listFilesRecursive ../../../theme/scripts;
  tokenInventory = lib.unique (
    lib.concatMap (file: tokensInText (builtins.readFile file)) themeSourceFiles
  );
  missingTokens = builtins.filter (token: !(builtins.elem token allPlaceholders)) tokenInventory;

  # Force this on every evaluation path, including static.env.
  allTokenValues =
    if missingTokens == [ ] then
      rawTokenValues
    else
      throw "theme: no replacement for placeholders: ${lib.concatStringsSep ", " missingTokens}";

  # Fail when a rendered file still contains a placeholder it does not own.
  # theme-apply keeps common placeholders on purpose: they are its runtime sed
  # patterns, not unresolved build-time substitutions.
  checkRendered =
    name: allowed: text:
    let
      leftover = builtins.filter (token: !(builtins.elem token allowed)) (tokensInText text);
    in
    if leftover == [ ] then
      text
    else
      throw "theme: ${name} has unresolved placeholders: ${lib.concatStringsSep ", " leftover}";

  renderTheme = file: replaceMany commonReplacements file;
  waybarSeed = pkgs.writeText "theme-waybar.css" (
    checkRendered "theme-waybar.css" [ ] (renderTheme ../../../theme/templates/waybar.css.template)
  );
  rofiSeed = pkgs.writeText "theme-rofi.rasi" (
    checkRendered "theme-rofi.rasi" [ ] (renderTheme ../../../theme/templates/rofi.rasi.template)
  );
  hyprlockSeed = pkgs.writeText "theme-hyprlock.conf" (
    checkRendered "theme-hyprlock.conf" [ ] (
      renderTheme ../../../theme/templates/hyprlock.conf.template
    )
  );
  hyprlandSeed = pkgs.writeText "theme-hyprland-decoration.conf" (
    checkRendered "theme-hyprland-decoration.conf" [ ] (
      renderTheme ../../../theme/templates/hyprland-decoration.conf.template
    )
  );
  nvimSeed = pkgs.writeText "theme-nvim-matugen.lua" (
    checkRendered "theme-nvim-matugen.lua" [ ] (
      renderTheme ../../../theme/templates/nvim-colors.lua.template
    )
  );
  hyprpaperSeed = pkgs.writeText "theme-hyprpaper.conf" (
    checkRendered "theme-hyprpaper.conf" [ ] (
      renderTheme ../../../theme/templates/hyprpaper.conf.template
    )
  );
  dunstSeed = pkgs.writeText "theme-dunstrc" (
    checkRendered "theme-dunstrc" [ ] (renderTheme ../../../theme/templates/dunstrc.template)
  );
  paletteSeed = pkgs.writeText "theme-palette.json" (
    builtins.toJSON {
      source = "static-fallback";
      inherit (theme) colors;
      inherit signal;
    }
  );

  # theme-apply injects the common values at runtime, so those placeholders must
  # survive build-time replacement and remain the only allowed leftovers.
  commonPlaceholders = map placeholder (builtins.attrNames commonTokenValues);
  themeApplyScript = checkRendered "theme-apply" commonPlaceholders (
    replaceMany themeBinReplacements ../../../theme/scripts/theme-apply.sh.template
  );
  wallpaperScript = checkRendered "wallpaper" [ ] (
    replaceMany themeBinReplacements ../../../theme/scripts/wallpaper.sh.template
  );
  wallpaperPortalScript = checkRendered "wallpaper-portal" [ ] (
    replaceMany themeBinReplacements ../../../theme/scripts/wallpaper-portal.sh.template
  );

  themeLockScript = checkRendered "theme-lock" [ ] (
    replaceMany (
      commonReplacements ++ themeBinReplacements
    ) ../../../theme/scripts/theme-lock.sh.template
  );

  staticEnvLine = name: value: "${name}=${lib.escapeShellArg value}";
  staticEnvTokenLine =
    entry: staticEnvLine (builtins.elemAt entry 0) allTokenValues.${builtins.elemAt entry 1};
  staticEnvTokenLines = [
    [
      "THEME_UI_FONT"
      "UI_FONT"
    ]
    [
      "THEME_UI_FONT_SIZE"
      "UI_FONT_SIZE"
    ]
    [
      "THEME_ROFI_FONT_SIZE"
      "ROFI_FONT_SIZE"
    ]
    [
      "THEME_ROFI_FONT_LABEL_SIZE"
      "ROFI_FONT_LABEL_SIZE"
    ]
    [
      "THEME_ROFI_FONT_SUBTITLE_SIZE"
      "ROFI_FONT_SUBTITLE_SIZE"
    ]
    [
      "THEME_ROFI_FONT_CALENDAR_SIZE"
      "ROFI_FONT_CALENDAR_SIZE"
    ]
    [
      "THEME_ROFI_FONT_VALUE_SIZE"
      "ROFI_FONT_VALUE_SIZE"
    ]
    [
      "THEME_ROFI_FONT_TITLE_SIZE"
      "ROFI_FONT_TITLE_SIZE"
    ]
    [
      "THEME_MONO_FONT"
      "MONO_FONT"
    ]
    [
      "THEME_LOCK_FONT"
      "LOCK_FONT"
    ]
    [
      "THEME_LOCK_FONT_BOLD"
      "LOCK_FONT_BOLD"
    ]
    [
      "THEME_LOCK_CLOCK_SIZE"
      "LOCK_CLOCK_SIZE"
    ]
    [
      "THEME_LOCK_TEXT_SIZE"
      "LOCK_TEXT_SIZE"
    ]
    [
      "THEME_STATIC_BASE"
      "BASE"
    ]
    [
      "THEME_STATIC_MANTLE"
      "MANTLE"
    ]
    [
      "THEME_STATIC_TEXT"
      "TEXT"
    ]
    [
      "THEME_STATIC_SUBTEXT"
      "SUBTEXT"
    ]
    [
      "THEME_STATIC_ACCENT"
      "ACCENT"
    ]
    [
      "THEME_STATIC_SUCCESS"
      "SUCCESS"
    ]
    [
      "THEME_STATIC_WARNING"
      "WARNING"
    ]
    [
      "THEME_STATIC_ERROR"
      "ERROR"
    ]
    [
      "THEME_STATIC_PURPLE"
      "PURPLE"
    ]
    [
      "THEME_STATIC_CYAN"
      "CYAN"
    ]
    [
      "THEME_SIGNAL_OK"
      "SIGNAL_OK"
    ]
    [
      "THEME_SIGNAL_NOTICE"
      "SIGNAL_NOTICE"
    ]
    [
      "THEME_SIGNAL_WARNING"
      "SIGNAL_WARNING"
    ]
    [
      "THEME_SIGNAL_CRITICAL"
      "SIGNAL_CRITICAL"
    ]
    [
      "THEME_SIGNAL_ECO"
      "SIGNAL_ECO"
    ]
    [
      "THEME_SIGNAL_MUTED"
      "SIGNAL_MUTED"
    ]
  ];
  staticEnvText = lib.concatMapStrings (line: "${line}\n") (
    [
      (staticEnvLine "THEME_GENERATOR_VERSION" "v9")
      (staticEnvLine "THEME_RUNTIME_ENABLE" (if theme.runtime.enable then "1" else "0"))
      (staticEnvLine "THEME_TEMPLATE_DIR" themeTemplatesDir)
      (staticEnvLine "THEME_GENERATED_DIR" themeGeneratedDir)
      (staticEnvLine "THEME_STATE_DIR" themeStateDir)
      (staticEnvLine "THEME_WALLPAPER_STORE" themeWallpaperStore)
      (staticEnvLine "THEME_WALLPAPER_POINTER" themeWallpaperPointer)
      (staticEnvLine "THEME_WALLPAPER_LOCK_FILE" "${themeStateDir}/wallpaper.lock")
      (staticEnvLine "THEME_LOCK_FILE" themeLockFile)
      (staticEnvTokenLine [
        "THEME_WALLPAPER"
        "WALLPAPER_PATH"
      ])
      (staticEnvLine "THEME_WALLPAPER_DROP_DIR" wallpaperDropDir)
    ]
    ++ map staticEnvTokenLine staticEnvTokenLines
  );

in
{
  assertions = [
    {
      assertion = missingTokens == [ ];
      message = "theme templates/scripts contain placeholders without replacements: ${lib.concatStringsSep ", " missingTokens}";
    }
  ];

  # GTK3 ignores the portal color-scheme and needs this setting.
  # GTK4/libadwaita follows the portal and warns if this key is set.
  gtk = {
    enable = true;
    gtk3.extraConfig."gtk-application-prefer-dark-theme" = true;
  };

  xdg.configFile = {
    "theme/templates".source = ../../../theme/templates;
    "theme/static.env".text = staticEnvText;
    "theme/theme-apply" = {
      text = themeApplyScript;
      executable = true;
    };
    "theme/wallpaper-portal" = {
      text = wallpaperPortalScript;
      executable = true;
    };

    "nvim/colors/matugen.lua".source = generatedLink "nvim-matugen.lua";
    "nvim/plugin/matugen.lua".text = ''
      vim.opt.termguicolors = true
      pcall(vim.cmd.colorscheme, "matugen")
    '';

    "hypr/hyprpaper.conf".source = generatedLink "hyprpaper.conf";

    # Link to theme-apply output so Home Manager cannot overwrite runtime changes.
    "dunst/dunstrc".source = generatedLink "dunstrc";
  };

  # Create a writable wallpaper directory without making it Home Manager-owned.
  home.activation.wallpaperDropDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg wallpaperDropDir}
  '';

  home = {
    file = {
      ".local/bin/theme-lock" = {
        text = themeLockScript;
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
        if [ ! -e "${themeGeneratedDir}/dunstrc" ]; then
          ${pkgs.coreutils}/bin/cp "${dunstSeed}" "${themeGeneratedDir}/dunstrc"
        fi
        if [ ! -e "${themeGeneratedDir}/palette.json" ]; then
          ${pkgs.coreutils}/bin/cp "${paletteSeed}" "${themeGeneratedDir}/palette.json"
        fi
      '';

      # Wait for seeding and systemd reload before applying the theme.
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

}
