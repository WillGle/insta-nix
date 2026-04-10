# How to use Atomic Note 󰠮

Atomic Note is a minimalist task manager integrated into your Waybar. It helps you focus on your most important (top) task while keeping your list easily accessible.

## 1. Quick Usage from Waybar

- **Idle View:** The center of your bar shows your **highest priority task** and a count of how many more are in your list.
- **Hover:** Move your mouse over the task to see a tooltip with your **top 5 tasks**.
- **Left-click:** Open the Rofi task menu.
- **Right-click:** Open the Rofi quick-add prompt.

## 2. Managing Tasks (CLI)

You can manage your tasks from any terminal using the `atomic-note` command.

### Open the Rofi Menu

```bash
atomic-note rofi
```

The Rofi menu lets you:

- add a task
- open the raw task file in a terminal editor
- clear all tasks with confirmation
- select an existing task and:
  - mark it done
  - edit it
  - move it to the top

### Add a Task

```bash
# Add a task with a priority tag ([A] is urgent, [B] is warning)
atomic-note add "[A] Fix the production bug"
atomic-note add "[B] Buy groceries"
```

If you run `atomic-note add` without text, it opens a Rofi prompt for quick entry.

### List All Tasks

```bash
atomic-note list
```

### Clear All Tasks

```bash
atomic-note clear
```

### Manual Edit

```bash
atomic-note edit
```

`atomic-note edit` opens the Rofi menu. If you want the raw task file in a terminal editor, use:

```bash
atomic-note file
```

## 3. Formatting & Priority

The Waybar module looks for `[A]` or `[B]` at the beginning of your tasks to apply colors:

- **`[A]` (Urgent):** Red text and underline.
- **`[B]` (Warning):** Orange/Peach text and underline.
- **`Empty`:** Grayed out icon.

---
*Tasks are stored in `~/.atomic_tasks`*
