#!/usr/bin/env bash
# VibeWM v3.0 — Polybar launcher (called by i3 autostart)
killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.5; done
polybar vibewm 2>&1 | tee -a /tmp/polybar.log & disown
