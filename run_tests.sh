#!/usr/bin/env bash
# Headless GUT runner. Usage: bash run_tests.sh [extra gut args]
GODOT="/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
# Import first to register GUT class_names (required on first run / fresh checkout)
"$GODOT" --headless --import 2>/dev/null
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json "$@"
