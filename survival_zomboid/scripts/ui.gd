extends CanvasLayer
## All menus / HUD, built in code (no scene editing needed).

var game = null

var main_menu: Control
var menu_message: Label
var high_label: Label
var hud: Control
var shop_overlay: Control
var shop_list: VBoxContainer
var shop_money: Label
var settings_overlay: Control
var minimap: Control

var round_label: Label
var zombies_label: Label
var money_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var stamina_bar: ProgressBar
var stamina_label: Label
var ammo_label: Label
var shop_btn: Button
var settings_btn: Button
var sprint_btn: Button
var touch: Control
var shop_status: Label
var hotbar: HBoxContainer
var _hotbar_sig := ""


func _ready() -> void:
	layer = 10
	_build_hud()
	_build_main_menu()
	_build_shop()
	_build_settings()


func setup(g) -> void:
	game = g
	minimap.game = g
	touch.game = g


# ------------------------------------------------------------------ helpers
func _sb(bg: Color, border := Color(0, 0, 0, 0), radius := 12, bw := 1, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


func _lbl(text: String, size := 16, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(text: String, bg: Color, fg := Color.WHITE, size := 16, radius := 10, pop := true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _sb(bg, bg.lightened(0.3), radius, 1, 10))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.15), bg.lightened(0.4), radius, 1, 10))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.2), bg.lightened(0.2), radius, 1, 10))
	b.add_theme_stylebox_override("disabled", _sb(bg.darkened(0.55), bg.darkened(0.3), radius, 1, 10))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", fg.darkened(0.5))
	b.add_theme_font_size_override("font_size", size)
	if pop:
		b.pressed.connect(_pop)
	return b


func _pop() -> void:
	Audio.play("pop")


func _icon_btn(kind: String, bg: Color, d := 46.0) -> Button:
	var b := _btn("", bg, Color.WHITE, 16, int(d / 2.0))
	b.custom_minimum_size = Vector2(d, d)
	var gl := Control.new()
	gl.set_script(load("res://scripts/icon_glyph.gd"))
	gl.kind = kind
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(gl)
	gl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return b


func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _make_overlay(dim: Color) -> Control:
	var root := Control.new()
	add_child(root)
	_full(root)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = dim
	root.add_child(bg)
	_full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	return root


func _center(root: Control) -> CenterContainer:
	var c := CenterContainer.new()
	root.add_child(c)
	_full(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _panel(parent: Node, bg: Color, border: Color, min_w: float) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(bg, border, 20, 2, 22))
	p.custom_minimum_size = Vector2(min_w, 0)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	return v


func _ignore(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	hud = Control.new()
	add_child(hud)
	_full(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false

	touch = Control.new()
	touch.set_script(load("res://scripts/touch_controls.gd"))
	hud.add_child(touch)
	_full(touch)
	touch.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	hud.add_child(margin)
	_full(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)

	var root := VBoxContainer.new()
	margin.add_child(root)
	_ignore(root)

	# ---- top bar
	var top := HBoxContainer.new()
	root.add_child(top)
	_ignore(top)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	top.add_child(left)
	_ignore(left)

	shop_btn = _icon_btn("shop", Color("#d97706"))
	shop_btn.disabled = true
	shop_btn.pressed.connect(func(): game.open_shop())
	left.add_child(shop_btn)
	shop_status = _lbl("(Locked)", 11, Color("#fde68a"))
	left.add_child(shop_status)
	settings_btn = _icon_btn("gear", Color("#334155"))
	settings_btn.pressed.connect(func(): game.open_settings())
	left.add_child(settings_btn)

	var mid := VBoxContainer.new()
	top.add_child(mid)
	_ignore(mid)
	round_label = _lbl("ROUND 1", 18, Color("#34d399"))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(round_label)
	zombies_label = _lbl("ZOMBIES LEFT: 8", 12, Color("#fcd34d"))
	zombies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(zombies_label)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 10)
	top.add_child(right)
	_ignore(right)

	minimap = Control.new()
	minimap.set_script(load("res://scripts/minimap.gd"))
	minimap.custom_minimum_size = Vector2(120, 120)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(minimap)
	money_label = _lbl("$100", 24, Color("#facc15"))
	money_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(money_label)

	# ---- spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)
	_ignore(spacer)

	# ---- bottom bar
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	_ignore(bottom)

	var bars := PanelContainer.new()
	bars.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.09, 0.16, 0.9), Color("#334155"), 12, 1, 8))
	bars.custom_minimum_size = Vector2(210, 0)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bars)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bars.add_child(bv)
	_ignore(bv)

	var hp_row := HBoxContainer.new()
	bv.add_child(hp_row)
	_ignore(hp_row)
	var hp_title := _lbl("HEALTH", 11, Color("#fb7185"))
	hp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp_title)
	hp_label = _lbl("100 / 100", 11)
	hp_row.add_child(hp_label)
	hp_bar = _make_bar(Color("#ef4444"))
	bv.add_child(hp_bar)

	var st_row := HBoxContainer.new()
	bv.add_child(st_row)
	_ignore(st_row)
	var st_title := _lbl("STAMINA", 10, Color("#38bdf8"))
	st_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_row.add_child(st_title)
	stamina_label = _lbl("100%", 10, Color("#cbd5e1"))
	st_row.add_child(stamina_label)
	stamina_bar = _make_bar(Color("#38bdf8"))
	bv.add_child(stamina_bar)

	var mid_box := VBoxContainer.new()
	mid_box.add_theme_constant_override("separation", 4)
	bottom.add_child(mid_box)
	_ignore(mid_box)
	ammo_label = _lbl("AMMO: ∞", 14, Color("#22d3ee"))
	mid_box.add_child(ammo_label)

	# round sprint button, placed above the right joystick
	sprint_btn = _icon_btn("run", Color("#0284c7"), 68.0)
	sprint_btn.button_down.connect(func(): game.sprint_hold = true)
	sprint_btn.button_up.connect(func(): game.sprint_hold = false)
	hud.add_child(sprint_btn)
	sprint_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sprint_btn.offset_right = -(170.0 - 34.0)
	sprint_btn.offset_left = sprint_btn.offset_right - 68.0
	sprint_btn.offset_bottom = -(345.0 - 34.0)
	sprint_btn.offset_top = sprint_btn.offset_bottom - 68.0

	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp2)
	_ignore(sp2)

	hotbar = HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 6)
	hotbar.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(hotbar)
	_ignore(hotbar)


func _make_bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = 100
	b.value = 100
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 10)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", _sb(Color("#020617"), Color("#1e293b"), 5, 1, 0))
	b.add_theme_stylebox_override("fill", _sb(color, Color(0, 0, 0, 0), 5, 0, 0))
	return b


func refresh_hud() -> void:
	if game == null:
		return
	round_label.text = "ROUND %d" % game.round_num
	zombies_label.text = "ZOMBIES LEFT: %d" % maxi(0, game.zombies_remaining)
	money_label.text = "$%d" % game.money
	hp_bar.value = clampf(game.health / game.max_health * 100.0, 0.0, 100.0)
	hp_label.text = "%d / %d" % [int(round(game.health)), int(game.max_health)]
	var sp: float = game.stamina / game.max_stamina * 100.0
	stamina_bar.value = sp
	stamina_label.text = "%d%%" % int(round(sp))
	var w: Dictionary = game.WEAPONS[game.current_weapon]
	if w["infinite"]:
		ammo_label.text = "AMMO: ∞"
	else:
		ammo_label.text = "AMMO: %d" % game.weapon_ammo[game.current_weapon]["reserve"]
	shop_btn.disabled = game.round_active
	sprint_btn.modulate = Color(1.35, 1.35, 1.35) if game.sprint_hold else Color.WHITE
	shop_status.text = "(Locked)" if game.round_active else "(Open)"
	minimap.queue_redraw()
	_refresh_hotbar()


func is_sprint_at(pos: Vector2) -> bool:
	return hud.visible and sprint_btn.get_global_rect().grow(8.0).has_point(pos)


func is_over_button(pos: Vector2) -> bool:
	if not hud.visible:
		return false
	var list: Array = [shop_btn, settings_btn, sprint_btn]
	list.append_array(hotbar.get_children())
	for b in list:
		if b is Control and b.get_global_rect().grow(8.0).has_point(pos):
			return true
	return false


func _refresh_hotbar() -> void:
	var sig: String = ",".join(PackedStringArray(game.owned_weapons)) + "|" + str(game.current_weapon)
	if sig == _hotbar_sig:
		return
	_hotbar_sig = sig
	for c in hotbar.get_children():
		c.queue_free()
	var idx := 1
	for key in game.owned_weapons:
		var active: bool = key == game.current_weapon
		var b := _btn("%d\n%s" % [idx, key.substr(0, 1)],
			Color("#059669") if active else Color("#1e293b"),
			Color.WHITE if active else Color("#94a3b8"), 13, 10, false)
		b.custom_minimum_size = Vector2(46, 46)
		var k: String = key
		b.pressed.connect(func(): game.select_weapon(k))
		hotbar.add_child(b)
		idx += 1


# ------------------------------------------------------------------ main menu
func _build_main_menu() -> void:
	main_menu = _make_overlay(Color(0.008, 0.024, 0.09, 0.95))
	var v := _panel(_center(main_menu), Color(0.06, 0.09, 0.16, 0.95), Color("#064e3b"), 400)
	v.add_theme_constant_override("separation", 14)

	var title := _lbl("SURVIVAL ZOMBOID", 34, Color("#b5c93a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _lbl("TACTICAL FOREST SURVIVAL", 12, Color("#34d399"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	menu_message = _lbl("", 14, Color("#fb7185"))
	menu_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(menu_message)

	var hs := PanelContainer.new()
	hs.add_theme_stylebox_override("panel", _sb(Color(0.26, 0.15, 0.03, 0.5), Color("#b4781e"), 14, 1, 8))
	v.add_child(hs)
	high_label = _lbl("HIGHEST ROUND: 1", 18, Color("#fcd34d"))
	high_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hs.add_child(high_label)

	var start := _btn("Start Game", Color("#059669"), Color.WHITE, 22)
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(func(): game.start_new_game())
	v.add_child(start)

	var st := _btn("Settings", Color("#1e293b"), Color("#cbd5e1"), 16)
	st.pressed.connect(func(): game.open_settings())
	v.add_child(st)

	if OS.get_name() != "Web":
		var q := _btn("Quit", Color("#1e293b"), Color("#fb7185"), 16)
		q.pressed.connect(func(): game.quit_game())
		v.add_child(q)

	var help := _lbl("WASD move  |  Shift sprint  |  Mouse aim  |  Click / Space fire  |  1-5 weapons  |  Esc pause", 11, Color("#64748b"))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(340, 0)
	v.add_child(help)


func show_main_menu(message := "") -> void:
	menu_message.text = message
	menu_message.visible = message != ""
	high_label.text = "HIGHEST ROUND: %d" % game.highest_round
	main_menu.visible = true
	hud.visible = false
	shop_overlay.visible = false
	settings_overlay.visible = false
	Audio.stop_bgm()
	Audio.start_menu_music()


func show_hud() -> void:
	main_menu.visible = false
	shop_overlay.visible = false
	settings_overlay.visible = false
	hud.visible = true
	Audio.stop_menu_music()
	_hotbar_sig = ""
	refresh_hud()


# ------------------------------------------------------------------ shop
func _build_shop() -> void:
	shop_overlay = _make_overlay(Color(0.008, 0.024, 0.09, 0.9))
	var v := _panel(_center(shop_overlay), Color("#0f172a"), Color("#065f46"), 560)

	var head := HBoxContainer.new()
	v.add_child(head)
	var t := _lbl("Intermission Shop & Supplies", 20, Color("#facc15"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	shop_money = _lbl("$0", 18, Color("#fde047"))
	head.add_child(shop_money)
	var x := _icon_btn("close", Color("#334155"), 40.0)
	x.pressed.connect(func(): game.close_shop())
	head.add_child(x)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 8)
	scroll.add_child(shop_list)

	var nxt := _btn("Start Next Round", Color("#059669"), Color.WHITE, 20)
	nxt.custom_minimum_size = Vector2(0, 46)
	nxt.pressed.connect(func(): game.start_next_round_from_shop())
	v.add_child(nxt)


func _shop_row(title: String, sub: String) -> HBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.12, 0.16, 0.23, 0.9), Color("#334155"), 12, 1, 10))
	shop_list.add_child(p)
	var h := HBoxContainer.new()
	p.add_child(h)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(vb)
	vb.add_child(_lbl(title, 15, Color("#e2e8f0")))
	if sub != "":
		vb.add_child(_lbl(sub, 11, Color("#94a3b8")))
	return h


func show_shop() -> void:
	for c in shop_list.get_children():
		c.queue_free()
	shop_money.text = "$%d" % game.money

	for key in game.WEAPONS.keys():
		var w: Dictionary = game.WEAPONS[key]
		var owned: bool = game.owned_weapons.has(key)
		var row := _shop_row(w["name"], "Dmg: %d | Rate: %dms" % [int(w["damage"]), int(w["fire_rate"])])
		var k: String = key
		if owned:
			if w["infinite"]:
				row.add_child(_lbl("∞ ammo", 13, Color("#34d399")))
			else:
				var b := _btn("Ammo ($%d)" % int(w["ammo_cost"]), Color("#047857"), Color.WHITE, 13)
				b.disabled = game.money < int(w["ammo_cost"])
				b.pressed.connect(func(): game.buy_ammo(k))
				row.add_child(b)
		else:
			var b := _btn("Buy ($%d)" % int(w["cost"]), Color("#d97706"), Color.WHITE, 13)
			b.disabled = game.money < int(w["cost"])
			b.pressed.connect(func(): game.buy_weapon(k))
			row.add_child(b)

	for key in game.HEALING_ITEMS.keys():
		var h: Dictionary = game.HEALING_ITEMS[key]
		var row := _shop_row("%s (+%d HP)" % [h["name"], int(h["heal"])], "")
		var k: String = key
		var b := _btn("Buy ($%d)" % int(h["cost"]), Color("#be123c"), Color.WHITE, 13)
		b.disabled = game.money < int(h["cost"]) or game.health >= game.max_health
		b.pressed.connect(func(): game.buy_heal(k))
		row.add_child(b)

	shop_overlay.visible = true


func hide_shop() -> void:
	shop_overlay.visible = false


# ------------------------------------------------------------------ settings
func _build_settings() -> void:
	settings_overlay = _make_overlay(Color(0.008, 0.024, 0.09, 0.9))
	var v := _panel(_center(settings_overlay), Color("#0f172a"), Color("#1e293b"), 420)

	v.add_child(_lbl("Settings & Pause", 24, Color("#f1f5f9")))

	var cb := CheckBox.new()
	cb.text = "Camera Shake"
	cb.button_pressed = true
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(on):
		game.camera_shake_on = on
		Audio.play("pop"))
	v.add_child(cb)

	v.add_child(_slider_row("Master Volume", 0.8, func(x): Audio.set_master(x)))
	v.add_child(_slider_row("Music Volume", 0.5, func(x): Audio.set_music(x)))
	v.add_child(_slider_row("SFX Volume", 0.8, _set_sfx))

	var resume := _btn("Resume Game", Color("#059669"), Color.WHITE, 18)
	resume.custom_minimum_size = Vector2(0, 44)
	resume.pressed.connect(func(): game.close_settings())
	v.add_child(resume)

	var quit := _btn("Quit to Main Menu", Color("#1e293b"), Color("#fb7185"), 16)
	quit.pressed.connect(func(): game.quit_to_menu())
	v.add_child(quit)


func _slider_row(title: String, initial: float, cb: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	box.add_child(head)
	var n := _lbl(title, 14, Color("#cbd5e1"))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	var val := _lbl("%d%%" % int(round(initial * 100.0)), 14, Color("#cbd5e1"))
	head.add_child(val)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = initial
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(0, 22)
	s.value_changed.connect(_on_slider.bind(val, cb))
	s.drag_ended.connect(func(_changed): Audio.play("pop"))
	box.add_child(s)
	return box


func _on_slider(x: float, val: Label, cb: Callable) -> void:
	val.text = "%d%%" % int(round(x * 100.0))
	cb.call(x)


func _set_sfx(x: float) -> void:
	Audio.set_sfx(x)


func show_settings() -> void:
	settings_overlay.visible = true


func hide_settings() -> void:
	settings_overlay.visible = false
