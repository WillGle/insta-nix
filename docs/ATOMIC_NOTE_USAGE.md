# How To Use Atomic Note

Atomic Note is a small task queue integrated into Waybar and managed through `atomic-note`.

## Integration Notes

Atomic Note currently depends on these files:

- `dotfiles/hosts/.../local-bin/atomic-note`: main script for task storage, Waybar JSON rendering, and the Rofi menus
- `dotfiles/common/waybar/config.jsonc`: Waybar module wiring for `custom/atomic_note`
- your Home Manager host module: installs the script as `~/.local/bin/atomic-note`

Recent related changes that matter operationally:

- The old `waybar-atomic-note` helper script was removed.
- Waybar now calls `atomic-note render-waybar` directly.
- Atomic Note was migrated from Wofi to Rofi.

Because `~/.local/bin/atomic-note` is Home Manager-managed, editing the repo copy alone does not update the live command until you apply the system configuration.

## Waybar Behavior

- The Waybar module shows the first task in `~/.atomic_tasks`, not an automatically sorted highest-priority task.
- If more tasks exist, Waybar appends the remaining count in parentheses.
- Hovering the module shows up to 5 tasks in the tooltip, each prefixed with its normalized priority label.
- Left-click opens the Rofi menu.
- Right-click opens the quick-add flow.

Waybar styling follows the first task's priority:

- `Critical`: error/red
- `High`: warning/orange
- `Moderate`: accent/blue
- `Low`: success/green
- `Empty`: subdued/gray

The current Waybar module wiring is:

- `exec`: `~/.local/bin/atomic-note render-waybar`
- `on-click`: `~/.local/bin/atomic-note rofi`
- `on-click-right`: `~/.local/bin/atomic-note add`
- `signal`: `5`

## Commands

Use these commands from a terminal:

```bash
atomic-note rofi
atomic-note edit
atomic-note add "Fix the production bug" critical
atomic-note file
atomic-note list
atomic-note clear
```

`atomic-note rofi` and `atomic-note edit` currently do the same thing: open the Rofi menu.

`atomic-note file` opens the raw task file in a terminal editor launched through `foot`. It uses `$EDITOR` if set, otherwise falls back to `nano`, then `vi`.

`atomic-note render-waybar` is the internal subcommand used by Waybar. It outputs JSON for the module text, tooltip, and CSS class.

## Rofi Menu

The current Rofi layout is:

1. Search bar at the top
2. Action row with `Add`, `Open`, and `Clear`
3. Two task columns below

The action row supports both mouse clicks and keyboard shortcuts:

- `Add`: click the button or press `Alt+1`
- `Open`: click the button or press `Alt+2`
- `Clear`: click the button or press `Alt+3`

Task rows are split into two columns:

- Left column: `Critical / High`
- Right column: `Moderate / Low`

Selecting a task opens a secondary menu with:

- `Mark done`
- `Edit task`
- `Change priority`
- `Move to top`
- `Cancel`

`Clear` always asks for confirmation before truncating the task file.

## Adding Tasks

Add a task directly:

```bash
atomic-note add "Reply to email thread" high
atomic-note add "Refactor config comments" moderate
atomic-note add "Tidy downloads" low
```

If you run `atomic-note add` without task text, it opens:

1. A Rofi prompt for the task body
2. A Rofi priority picker

Accepted priority inputs:

- `critical`
- `crit`
- `p0`
- `a`
- `high`
- `p1`
- `b`
- `moderate`
- `medium`
- `med`
- `normal`
- `default`
- `p2`
- `c`
- `low`
- `p3`
- `d`

New writes are normalized to one of these stored forms:

```text
[Critical] Fix prod incident
[High] Reply to planner email
[Moderate] Refactor Waybar tooltip
[Low] Sort downloads
```

Older short forms like `[A]`, `[B]`, `[C]`, and `[D]` are still recognized when reading existing tasks.

## Common Flows

### Capture Something Quickly

1. Right-click the Waybar Atomic Note module.
2. Enter the task text.
3. Choose the priority.

### Reorder the Queue

1. Left-click the Waybar Atomic Note module.
2. Select a task.
3. Choose `Move to top`.

This changes what Waybar shows, because the module always renders the first task in the file.

### Edit The Raw File

```bash
atomic-note file
```

Tasks are stored in `~/.atomic_tasks`.
