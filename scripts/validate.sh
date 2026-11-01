#!/usr/bin/env bash
# Run the repository's minimum validation gate.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

git -C "$repo_root" diff --check
nix flake check --no-build --no-write-lock-file "$repo_root"

printf 'validation passed\n'
