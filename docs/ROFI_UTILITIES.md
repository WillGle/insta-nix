# Rofi Utilities Guide

This guide covers the Rofi-based screen-time dashboard on `laptop`.

## Screen Time (`rofi-screen-time`)

The dashboard reads the local day files written by the focused-window tracker.

### Views

- **Summary**: total screen time, 24-hour activity strip, top apps, top
  category, and sample tracking status.
- **Activity**: per-app timeline, busy hours, category breakdown, and unknown
  apps.

Historical days are available with the previous/next-day rows. The tracker
samples the focused window every 5 seconds; `swayidle` supplies `IdleHint` so
idle time is excluded.

### Usage

```bash
rofi-screen-time
rofi-screen-time --view activity
rofi-screen-time --date 2026-11-20
```

The popup caches one rendered view for 300 seconds. A stale or missing view is
rendered synchronously (about 2 seconds on a cold start); there is no background
cache service or timer.

The same data is available to scripts:

```bash
rofi-screen-time-stats --view summary --format json
rofi-screen-time-stats --view activity --format rows
```

Waybar exposes the screen-time module:

- Left-click toggles the Waybar module view.
- Right-click opens the screen-time dashboard.

## Data Retention

`home-cleanup` runs weekly and removes old user state:

- screen-time day history older than 180 days;
- Zed logs older than 14 days;
- cached entries in `~/.cache` that have not changed for 14 days;
- the generated Rofi desktop cache and old screen-time cache files.

Nix evaluation caches, editor and browser data, clip history, and other
user-facing caches are protected from the broad `~/.cache` sweep. Run
`home-cleanup --dry-run` to preview removals.

## Source Layout

- Dashboard module: `modules/desktop/apps/screen-time/`
- Generic Rofi platform and shared menu helpers: `modules/desktop/rofi/`
- Waybar module and helper: `modules/desktop/waybar/`
- Shared palette loader: `modules/desktop/theme/lib/palette.sh`
- Shared network helper: `modules/desktop/lib/network.sh`
