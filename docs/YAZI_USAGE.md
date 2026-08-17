# Yazi Advanced Usage Guide 🚀

This guide covers the full capabilities of your Yazi setup on NixOS, optimized for the **Foot terminal** with Sixel graphics support.

## 1. Core Navigation (Vim-style)

Yazi is designed for keyboard efficiency using standard Vim keys:

- `k` / `↑` : Move up
- `j` / `↓` : Move down
- `h` / `←` : Go to parent directory
- `l` / `→` : Enter directory or open file
- `Enter` : Open file or enter directory
- `q` : Quit Yazi
- `g g` : Go to top
- `G` : Go to bottom

## 2. Selection & Operations

- `Space` : Toggle selection of current file
- `v` : Enter **Visual Mode** (select multiple files by moving)
- `y` : **Copy** selected files
- `x` : **Cut** (Move) selected files
- `p` : **Paste** files
- `d` : **Delete** files (moves to trash)
- `r` : **Rename** file
- `A` : Create a new directory
- `a` : Create a new file

## 3. Tier 1: CLI Integrations

Your Yazi is supercharged with specialized CLI tools:

### ⚡ Smart Jump (`zoxide`)

- **Key**: `z`
- **Usage**: Press `z` then type a few letters of a directory you've visited before (e.g., `z nix`). Zoxide will instantly "jump" you there based on your history.

### 🔍 Fuzzy Finder (`fzf` & `fd`)

- **Key**: `/`
- **Usage**: Standard search is powered by `fd` for speed and `fzf` for fuzzy matching. You don't need to type exact names; just some characters in any order.

### � Content Search (`ripgrep`)

- Used internally to make file indexing and searching blazing fast.

## 4. Tier 2: Intelligent Defaults

Configured via Home Manager in `modules/home/base.nix`:

- **Hidden Files**: Automatically shown by default.
- **Sorting**: Files are sorted by **Modified Time** (`mtime`) by default (newest first).
- **Directories First**: Folders are always grouped at the top.
- **Shell Integration**: Deeply integrated with your `fish` shell.

## 5. Tier 3: Aesthetics & Rich Previews

### 🖼️ High-Fidelity Previews

- **Images**: Uses **Sixel** protocol (native to Foot). Yazi auto-detects this from `TERM=foot` — there is no config key for it.
- **Dimensions**: Previews are rendered at up to 1000x1000px for crisp detail.
- **Large photos**: `tasks.image_bound` is raised to 40000x40000 (default is 5000x5000). Without this, any 40MP photo fails to preview with `Image size exceeds limit`. The real safety net is `tasks.image_alloc` (2 GiB), which caps decode memory — note that the limit is driven by pixel count, not file size on disk.

### 🎨 Visual Theme

- **Theme**: Synced with your **GitHub Dark Dimmed** system theme.
- **Status Bar**: Shows the **File Size** (`linemode = size`) on the right side of the list.
- **Selection Highlight**: Uses your system **Accent Blue** for the hovered item with a black text contrast for high readability.

## 6. Pro Tips

- Use `~` to go to your Home directory instantly.
- Use `ctrl + s` (if configured) or standard search to filter large lists.
- Since you are on **Foot**, mouse scrolling and clicking work out of the box for quick navigation.

---
*Your Yazi setup is now one of the most optimized file managers on Wayland. Happy hacking!*
