# Remote Migration Runbook

This repo currently provides:

- `Laptop`: strict daily profile for the current laptop.
- `generic-installer`: generic installer profile (strict SSH non-root).

For new remote installs, use the dedicated public guide:

- [`docs/PLANK_REMOTE_INSTALL.md`](./PLANK_REMOTE_INSTALL.md)

Bootstrap output was removed in hard migration. Remote safety now relies on:

- deterministic install runbook,
- local-private key seeding,
- strict SSH policy validation post-install.
