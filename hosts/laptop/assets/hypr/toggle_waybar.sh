#!/usr/bin/env bash
set -euo pipefail
systemctl --user kill --signal=SIGUSR1 --kill-whom=main waybar.service
