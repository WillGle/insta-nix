# Yazi Usage Guide

Configured in `modules/home/terminal/default.nix`. Key bindings below match Yazi 26.5.6 defaults; uppercase keys are distinct.

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
- `a` : Create a file; end the name with `/` to create a directory

## 3. Tier 1: CLI Integrations

The package includes these tools:

### ⚡ Smart Jump (`zoxide`)

- **Key**: `Z`
- **Usage**: Search previously visited directories through zoxide.

### 🔍 Fuzzy Finder (`fzf` & `fd`)

- **Keys**: `z` opens fzf; `s` searches filenames with fd.
- **Other navigation**: `/` finds the next matching filename in the current listing; `f` filters the listing.

### Content Search (`ripgrep`)

- **Key**: `S` searches file contents with ripgrep. `Ctrl+s` cancels an ongoing search.

## 4. Tier 2: Intelligent Defaults

Configured via Home Manager in `modules/home/terminal/default.nix`:

- **Hidden Files**: Automatically shown by default.
- **Sorting**: Files are sorted by **Modified Time** (`mtime`); reverse sorting is not enabled.
- **Directories First**: Folders are always grouped at the top.
- **Shell Integration**: Deeply integrated with your `fish` shell.

## 5. Tier 3: Aesthetics & Rich Previews

### 🖼️ High-Fidelity Previews

- **Images**: Foot supports **Sixel** previews; Yazi detects the terminal's image capabilities.
- **Dimensions**: Previews are rendered at up to 1000x1000px for crisp detail.
- **Large photos**: `tasks.image_bound` is 40000x40000 (default: 10000x10000), and `tasks.image_alloc` is 2 GiB (default: 512 MiB). These limit image dimensions and decode memory, not file size on disk.
- **RAW**: `.CR2/.CR3/.NEF/.ARW/.DNG/.RAF/.ORF/.RW2/...` use the `magick` previewer with libraw support. Filename rules avoid unreliable RAW MIME detection. Initial decoding time depends on the file and hardware.

### 🪟 Opening Files (`Enter`)

Images, audio and video use `xdg-open`, with handlers from `xdg.mimeApps.defaultApplications` in `modules/home/xdg.nix`: **Loupe** for images, **VLC** for video, **Tauon** for audio.

Note that Yazi's own default sends `{audio,video}/*` straight to `mpv` instead, bypassing xdg entirely; since `mpv` isn't installed here, `Enter` on a video used to do nothing. The `open.prepend_rules` entry in `modules/home/terminal/default.nix` is what overrides that.

### 🎨 Visual Theme

- **Theme**: Uses Yazi's default flavor, with a custom hover color from `theme.colors.accent`.
- **Status Bar**: Shows the **File Size** (`linemode = size`) on the right side of the list.
- **Selection Highlight**: Uses the accent configured at rebuild time with black text. Wallpaper changes do not update Yazi's theme at runtime.

## 6. Pro Tips

- Use `g h` to go to your Home directory; `~` opens help.
- Use `f` to filter the current listing; `Ctrl+s` cancels a search.
- Since you are on **Foot**, mouse scrolling and clicking work out of the box for quick navigation.
