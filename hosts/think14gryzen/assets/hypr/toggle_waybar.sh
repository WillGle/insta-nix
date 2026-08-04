#!/usr/bin/env bash
systemctl --user kill --signal=SIGUSR1 --kill-whom=main waybar.service
