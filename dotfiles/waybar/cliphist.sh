#!/usr/bin/env bash

cliphist list | \
wofi \
  --conf ~/.config/wofi/config-clip.ini \
  --style ~/.config/wofi/style.css \
  --show dmenu \
  --prompt "Clipboard:" | \
cliphist decode | wl-copy
