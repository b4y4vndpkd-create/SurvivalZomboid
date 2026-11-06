# Survival Zomboid - Godot 4 port

Top-down tactical forest zombie survival, ported from the single-file HTML5 game.

## Import
1. Install **Godot 4.2 or newer** (standard build, no .NET needed).
2. Unzip this folder.
3. Open Godot -> Project Manager -> **Import** -> select `project.godot` -> Import & Edit.
4. Press **F5** to play.

## Controls
- Desktop: WASD / arrows move, Shift sprint, mouse aim, left click or Space fire, 1-5 switch weapon, Esc pause.
- Touch: left joystick moves, right joystick aims and auto-fires when pushed out, SPRINT button on the HUD.

## Project layout
- `main.tscn` - root scene (Game node, Camera2D, UI layer)
- `scripts/game.gd` - rounds, zombies, weapons, shop logic and all world drawing
- `scripts/ui.gd` - main menu, HUD, shop, settings (built in code)
- `scripts/minimap.gd` - radar
- `scripts/touch_controls.gd` - on-screen joysticks
- `scripts/icon_glyph.gd` - icons for the round Settings / Shop / close buttons
- `scripts/audio_manager.gd` - autoload `Audio`; all sound effects and music are synthesised in code

Highest round is saved to `user://survival_zomboid_save.json`.
Rendering uses the Compatibility renderer, so Web / mobile export works out of the box.
