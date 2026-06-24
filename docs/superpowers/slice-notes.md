# Combat Slice — how to run

- Play: `"/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --path .`
- Tests: `bash run_tests.sh`
- Single test file: `bash run_tests.sh -gtest=res://test/unit/test_sim_basic.gd`

## Tuning knobs
- Frames/damage/cost per move: `src/content/deck.gd`
- Combo recipes: `src/content/combos.gd`
- Stamina rewards/penalties + gasp: constants atop `src/combat/combat_sim.gd`
- Timeline length / gasp length: `CombatState` defaults
- Overcommit factor (1.5x): `Plan.is_valid`

## Next (post-slice)
Map/shop/relics/meta, more styles, art/audio, GodotSteam export.
