extends Control
## Draws the two on-screen joysticks (left = move, right = aim & auto-fire).

const R := 70.0

var game = null


func _process(_delta: float) -> void:
	var show_it: bool = game != null and game.in_game and not game.paused \
			and (DisplayServer.is_touchscreen_available() or game.using_touch)
	visible = show_it
	if show_it:
		queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var left_idle := Vector2(170.0, size.y - 230.0)
	var right_idle := Vector2(size.x - 170.0, size.y - 230.0)

	var move_base: Vector2 = game.stick_start if game.stick_active else left_idle
	var move_knob: Vector2 = game.stick_cur if game.stick_active else left_idle
	_stick(move_base, move_knob, game.stick_active, Color("#34d399"))

	var aim_on: bool = game.aim_index != -1
	var aim_base: Vector2 = game.aim_start if aim_on else right_idle
	var aim_knob: Vector2 = game.aim_cur if aim_on else right_idle
	var firing: bool = aim_on and (aim_knob - aim_base).length() > 24.0
	_stick(aim_base, aim_knob, aim_on, Color("#f87171") if firing else Color("#fbbf24"))


func _stick(base: Vector2, knob: Vector2, active: bool, col: Color) -> void:
	draw_circle(base, R, Color(col, 0.18 if active else 0.08))
	draw_arc(base, R, 0.0, TAU, 48, Color(col, 0.7 if active else 0.35), 3.0, true)
	var off := (knob - base).limit_length(R)
	draw_circle(base + off, 30.0, Color(col, 0.6 if active else 0.3))
	draw_arc(base + off, 30.0, 0.0, TAU, 32, Color(col, 0.9 if active else 0.5), 2.0, true)
