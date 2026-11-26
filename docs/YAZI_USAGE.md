# Yazi usage

Configured in `modules/cli/terminal.nix`. Core keys match Yazi 26.5.6 defaults;
integrations such as zoxide, fzf, fd, and ripgrep are added by the module.

## Navigation

| Key | Action |
|---|---|
| `k` / `↑` | Move up |
| `j` / `↓` | Move down |
| `h` / `←` | Parent directory |
| `l` / `→` | Enter directory or open file |
| `Enter` | Open file or enter directory |
| `gg` / `G` | Top / bottom |
| `gh` | Home directory |
| `q` | Quit |
| `~` | Help |

## Files

| Key | Action |
|---|---|
| `Space` | Select current file |
| `v` | Visual selection mode |
| `y` | Copy |
| `x` | Cut |
| `p` | Paste |
| `d` | Delete (trash) |
| `r` | Rename |
| `a` | Create file; end with `/` for a directory |

## Search and jump

| Key | Action |
|---|---|
| `Z` | Jump with zoxide |
| `z` | Fuzzy find with fzf |
| `s` | Search filenames with fd |
| `S` | Search contents with ripgrep |
| `/` | Find next match in current listing |
| `f` | Filter current listing |
| `Ctrl+s` | Cancel search |

## Behavior

- Hidden files are shown by default.
- Sort by modified time; directories stay on top.
- Shell integration uses `fish`.
- **Enter** on images, audio, and video uses `xdg-open` with the MIME defaults
  from `modules/desktop/mime.nix`: Loupe, VLC, Tauon.
- Yazi's default sends audio/video to `mpv`; `open.prepend_rules` in
  `modules/cli/terminal.nix` overrides that because `mpv` is not installed.

## Previews

- Foot supports Sixel; Yazi detects terminal image support.
- Images render up to 1000x1000.
- `tasks.image_bound` is 40000x40000 and `tasks.image_alloc` is 2 GiB. These
  limit dimensions and decode memory, not file size.
- RAW files use the `magick` previewer with libraw.

## Theme

- Yazi's default flavor, with the accent color from `theme.colors.accent`.
- Status bar shows file size (`linemode = size`).
- Accent is fixed at rebuild time; wallpaper changes do not update Yazi at
  runtime.

## Tips

- `f` filters the current listing; `Ctrl+s` cancels a search.
- On Foot, mouse scrolling and clicking work out of the box.
