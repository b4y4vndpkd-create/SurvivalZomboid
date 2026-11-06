extends Control
## Vector icon drawn on top of a round button ("gear", "shop", "close").

var kind := "gear"


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var btn := get_parent() as Button
	var col := Color.WHITE
	if btn and btn.disabled:
		col = Color(1, 1, 1, 0.4)
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.26
	match kind:
		"gear":
			draw_arc(c, r * 0.85, 0.0, TAU, 32, col, r * 0.55, true)
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0)
				draw_line(c + d * r, c + d * r * 1.5, col, r * 0.5, true)
		"shop":
			draw_rect(Rect2(c.x - r, c.y - r * 0.35, r * 2.0, r * 1.5), col)
			draw_arc(Vector2(c.x, c.y - r * 0.35), r * 0.55, PI, TAU, 14, col, 2.5, true)
		"run":
			var u := minf(size.x, size.y) * 0.3
			draw_circle(c + Vector2(0.4, -1.05) * u, u * 0.3, col)
			draw_polyline(PackedVector2Array([c + Vector2(0.25, -0.65) * u, c + Vector2(-0.1, 0.2) * u]), col, 4.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(0.2, -0.5) * u, c + Vector2(0.75, -0.15) * u, c + Vector2(1.0, -0.6) * u]), col, 3.5, true)
			draw_polyline(PackedVector2Array([c + Vector2(0.15, -0.5) * u, c + Vector2(-0.5, -0.35) * u, c + Vector2(-0.85, 0.0) * u]), col, 3.5, true)
			draw_polyline(PackedVector2Array([c + Vector2(-0.1, 0.2) * u, c + Vector2(0.6, 0.55) * u, c + Vector2(0.4, 1.15) * u]), col, 4.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-0.1, 0.2) * u, c + Vector2(-0.6, 0.65) * u, c + Vector2(-1.05, 0.4) * u]), col, 4.0, true)
		"close":
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, 3.0, true)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, 3.0, true)
