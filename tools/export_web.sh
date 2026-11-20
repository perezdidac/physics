#!/usr/bin/env bash
# Exports the web build to build/web/ using the "Web" preset of export_presets.cfg.
# Needs the Godot Web export templates (Editor → Manage Export Templates).
# Then serve it: python3 -m http.server -d build/web 8000
cd "$(dirname "$0")/.." || exit 1
G="${GODOT:-godot}"
mkdir -p build/web
"$G" --headless --path . --export-release "Web" build/web/index.html
