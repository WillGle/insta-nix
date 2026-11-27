# Atomic Note

Small task queue integrated into Waybar and provided by the
[rofi-hub](https://github.com/WillGle/rofi-hub) flake as
`services.rofi-apps.atomic-note`.

## Files

- rofi-hub `crates/atomic-note` — storage, Waybar JSON, Rofi menu, and priority
  glyphs.
- `modules/desktop/waybar/assets/config.jsonc` — `custom/atomic_note` module.
- `hosts/laptop/default.nix` — enables `services.rofi-apps.atomic-note`.

`atomic-note` is installed in the system profile. Do not add a second
`~/.local/bin/atomic-note`; the Waybar module calls the system command so the
menu uses the shared Rofi theme and app-owned theme state.

## Waybar

- Shows the first task in display order: highest priority, then file order.
  `Move to top` pins a task first.
- Appends the remaining count in parentheses.
- Hover shows every task with its priority glyph.
- Left-click opens the Rofi menu; right-click quick-adds; middle-click completes
  the shown task.
- Refreshes on signal 5 after every change, and polls every 30 seconds.

Priority styling:

| Priority | Color |
|---|---|
| Critical | error/red |
| High | warning/orange |
| Moderate | accent/blue |
| Low | success/green |
| Empty | subdued/gray |

## Commands

```bash
atomic-note rofi                 # menu (same as no argument)
atomic-note add "!! Fix prod"    # quick add with prefix
atomic-note add "Reply" high     # explicit priority wins
atomic-note done-top             # complete the task on the bar
atomic-note undo                 # restore the last done/clear batch
atomic-note file                 # edit ~/.atomic_tasks
atomic-note list
atomic-note clear
```

`atomic-note render-waybar` is internal, used by Waybar.

## Quick add

Type the task and press Enter. The prefix sets priority; no picker needed.

| Prefix | Priority |
|---|---|
| `!! text` | Critical |
| `! text` | High |
| *(none)* | Moderate |
| `- text` | Low |
| `[critical] text` | Critical (bracket form also works) |

`add` also accepts `critical`/`high`/`moderate`/`low`, `p0`–`p3`, or `a`–`d`;
the explicit argument overrides the prefix.

## Rofi menu

Top to bottom:

1. Actions: `Add  Alt+a` · `Open  Alt+o` · `Clear  Alt+x`
2. Filter box
3. Status line with counts and key hints
4. Sorted task list

| Key | Action |
|---|---|
| `Enter` | Per-task menu: done, edit, priority, move to top |
| `Alt+d` | Mark done |
| `Alt+e` | Edit text |
| `Alt+↑` | Move to top |
| `Alt+1`…`Alt+4` | Critical / High / Moderate / Low |
| `Alt+z` | Undo last done/clear |
| `Alt+a` / `Alt+o` / `Alt+x` | Add / open file / clear |
| `Esc` | Close |

## Storage

`~/.atomic_tasks` holds one task per line:

```text
[Critical] Fix prod incident
```

Older short forms `[A]`–`[D]` still work. Completed and cleared tasks go to
`~/.atomic_tasks.done` as `<batch epoch><TAB>line`; `undo` restores the most
recent batch.

## Common flows

### Capture quickly

Right-click the Waybar module, type `!! the thing`, press Enter.

### Finish the task on the bar

Middle-click the module. If you change your mind, open the menu and press
`Alt+z`.

### Work through the list

Left-click the module. Use `Alt+d` to complete, `Alt+1`–`Alt+4` to reprioritize,
and `Alt+↑` to pin a task first.

### Edit the raw file

```bash
atomic-note file
```
