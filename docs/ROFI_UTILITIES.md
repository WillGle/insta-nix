# Rofi Utilities Guide

This guide covers the specialized Rofi-based tools used for productivity tracking and system dashboards on `Laptop`.

## 1. Study Timer (`rofi-study-timer`)

The Study Timer is a Rofi interface for the underlying `study-timer` service. It allows you to manage focused work sessions with preset durations or custom plans.

### Features

- **Quick Start Presets**:
  - **Quick start**: 25 min, 1 session
  - **Pomodoro set**: 25 min, 4 sessions
  - **Deep work set**: 50 min, 2 sessions
  - **Long block**: 90 min, 1 session
- **Custom Study Plan**: Choose your own duration and session count.
- **Open-ended Session**: A classic timer without a fixed target.
- **Active Session View**: Shows elapsed time, progress bars for multi-session plans, and estimated finish time.
- **Plan Breakdown**: View the status (Completed/Pending) of individual sessions within a plan.

### Usage

Run the script from your terminal or via a keyboard shortcut:

```bash
rofi-study-timer
```

Left-click the Waybar module (if integrated) to open this menu.

---

## 2. Screen Time Dashboard (`rofi-screen-time`)

The Screen Time utility provides a visual dashboard of your computer usage and study totals.

### Features Summary

- **Summary View**: Highlights today's total active time and study progress.
- **Activity View**: Breaks down usage by application or category.
- **Historical Data**: Navigate through previous days to compare productivity.
- **Integrated Study Stats**: Pulls data directly from the Study Timer logs to show focused vs. unfocused time.

### Usage Instructions

```bash
rofi-screen-time
```

The dashboard is designed to be fast, using a popup-cache for immediate rendering of the today's summary.

---

## Integration Notes

Both tools are designed to work together:

- `rofi-study-timer` can launch `rofi-screen-time` via the "Open screen time" option.
- `rofi-screen-time` can launch the study timer via the study status row.
- Themes are located in `dotfiles/common/rofi/` (`study-timer.rasi` and `screen-time.rasi`).
