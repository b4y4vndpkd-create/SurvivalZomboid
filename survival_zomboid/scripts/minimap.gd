extends Control
## Small radar in the top-right corner.

var game = null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#172517"))
	if game == null:
		return
	var sc := size.x / float(game.MAP_SIZE)
	draw_rect(Rect2(Vector2(50, 50) * sc, Vector2(game.MAP_SIZE - 100, game.MAP_SIZE - 100) * sc), Color("#38220f"), false, 2.0)
	for z in game.zombies:
		draw_circle(z.pos * sc, 4.5 if z.is_boss else 2.2, Color("#c084fc") if z.is_boss else Color("#ef4444"))
	draw_circle(game.player_pos * sc, 3.5, Color("#22c55e"))
