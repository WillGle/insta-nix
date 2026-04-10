# Remote Migration Notes

## Status

- Archived
- Not the current recommended path for new installs

## Summary

This file keeps a short note about the older remote migration approach.

For current installs, use [`../guides/PLANK_REMOTE_INSTALL.md`](../guides/PLANK_REMOTE_INSTALL.md).

## Historical details

This repo currently provides:

- `Laptop`: main laptop configuration for the current laptop
- `generic-installer`: generic installer configuration with strict SSH settings

For new remote installs, use the dedicated public guide:

- [`../guides/PLANK_REMOTE_INSTALL.md`](../guides/PLANK_REMOTE_INSTALL.md)

Older bootstrap output was removed during the repo reorganization. The remaining historical note is that remote setup depended on:

- step-by-step install instructions
- local-private key seeding
- SSH validation after install

## References

- [`../README.md`](../README.md)
- [`rocm/README.md`](./rocm/README.md)
