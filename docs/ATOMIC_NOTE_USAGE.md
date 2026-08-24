# How To Use Atomic Note

Atomic Note is a small task queue integrated into Waybar and managed through `atomic-note`.

## Integration Notes

Atomic Note currently depends on these files:

- `hosts/think14gryzen/assets/local-bin/atomic-note`: main script for task storage, Waybar JSON rendering, and the Rofi menus
- `assets/common/waybar/config.jsonc`: Waybar module wiring for `custom/atomic_note`
- `modules/home/screen-time.nix`: installs the script as `~/.local/bin/atomic-note`

Because `~/.local/bin/atomic-note` is Home Manager-managed, editing the repo copy alone does not update the live command until you apply the system configuration.

## Waybar Behavior

- The module shows the **first task in display order**: highest priority first, then file order. A new task leads its priority group; `Move to top` puts a task first overall.
- If more tasks exist, the remaining count is appended in parentheses.
- Hovering shows **every** task in display order with its priority glyph.
- **Left-click** opens the Rofi menu. **Right-click** quick-adds. **Middle-click** marks the task shown on the bar as done (`Alt+z` in the menu undoes it).
- The module refreshes on signal 5, which the script sends after every change (including when the editor opened by `atomic-note file` closes); it also polls every 30 s.

Waybar styling follows the shown task's priority:

- `Critical`: error/red
- `High`: warning/orange
- `Moderate`: accent/blue
- `Low`: success/green
- `Empty`: subdued/gray

## Commands

```bash
atomic-note rofi                 # menu (also: edit, or no argument)
atomic-note add "!! Fix prod"    # quick add; prefix sets the priority
atomic-note add "Reply" high     # explicit priority argument wins
atomic-note done-top             # complete the task shown on the bar
atomic-note undo                 # restore the most recent done/clear batch
atomic-note file                 # open ~/.atomic_tasks in a terminal editor
atomic-note list
atomic-note clear
```

`atomic-note render-waybar` is the internal subcommand used by Waybar.

## Quick Add

One screen: type the task and press Enter. A prefix sets the priority, so there is no picker:

| Prefix | Priority |
| --- | --- |
| `!! text` | Critical |
| `! text` | High |
| *(none)* | Moderate |
| `- text` | Low |
| `[critical] text` … | the bracket spelling still works |

The priority argument to `add` (`critical`/`high`/`moderate`/`low`, `p0`–`p3`, `a`–`d`) overrides any prefix.

## Rofi Menu

Layout, top to bottom:

1. Action row: `Add  Alt+a` · `Open  Alt+o` · `Clear  Alt+x`
2. Filter box
3. Status line with counts and the key hints
4. One sorted list of tasks

Keys act on the highlighted row:

| Key | Action |
| --- | --- |
| `Enter` | per-task menu (Mark done · Edit · Change priority · Move to top) |
| `Alt+d` | mark done |
| `Alt+e` | edit text |
| `Alt+↑` | move to top |
| `Alt+1` … `Alt+4` | set priority Critical / High / Moderate / Low |
| `Alt+z` | undo the most recent done/clear |
| `Alt+a` / `Alt+o` / `Alt+x` | add / open file / clear (clear asks first) |
| `Esc` | close |

## Storage

`~/.atomic_tasks` holds one task per line:

```text
[Critical] Fix prod incident
```

Older short forms `[A]`–`[D]` are still recognised.

Completed and cleared tasks go to `~/.atomic_tasks.done` as `<batch epoch><TAB>line`; `undo` (or `Alt+z` in the menu) restores the most recent batch — one done task, or everything from one clear.

## Common Flows

### Capture Something Quickly

1. Right-click the module.
2. Type `!! the thing` (or plain text for Moderate) and press Enter.

### Finish The Task On The Bar

Middle-click the module. Changed your mind: open the menu and press `Alt+z`.

### Work Through The List

1. Left-click the module.
2. `Alt+d` on each finished task; `Alt+1`…`Alt+4` to re-prioritise; `Alt+↑` to pin one first.

### Edit The Raw File

```bash
atomic-note file
```
