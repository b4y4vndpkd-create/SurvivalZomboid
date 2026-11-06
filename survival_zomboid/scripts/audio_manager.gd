extends Node
## Procedural audio: every sound is synthesised in code, so no audio files are needed.

const RATE := 22050
const BGM_NOTES := [65.41, 65.41, 77.78, 65.41, 87.31, 65.41, 58.27, 65.41]
const MENU_MELODY := [220.0, 261.63, 329.63, 261.63, 196.0, 246.94, 293.66, 246.94,
		174.61, 220.0, 261.63, 220.0, 164.81, 196.0, 246.94, 196.0]
const MENU_BASS := [110.0, 110.0, 87.31, 82.41]

var master_vol := 0.8
var music_vol := 0.5
var sfx_vol := 0.8

var streams := {}
var sfx_players: Array[AudioStreamPlayer] = []
var music_players: Array[AudioStreamPlayer] = []
var bgm_timer: Timer
var bgm_step := 0
var menu_timer: Timer
var menu_step := 0


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	for i in 8:
		var m := AudioStreamPlayer.new()
		add_child(m)
		music_players.append(m)
	_build_streams()
	bgm_timer = Timer.new()
	bgm_timer.wait_time = 0.38
	bgm_timer.one_shot = false
	bgm_timer.timeout.connect(_on_bgm_tick)
	add_child(bgm_timer)
	menu_timer = Timer.new()
	menu_timer.wait_time = 0.45
	menu_timer.one_shot = false
	menu_timer.timeout.connect(_on_menu_tick)
	add_child(menu_timer)


# ---------------------------------------------------------------- synthesis
func _gen(kind: String, f0: float, f1: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(f0, f1, t)
		var env := (1.0 - t) * (1.0 - t)
		var s := 0.0
		match kind:
			"sine":
				s = sin(phase * TAU)
			"saw":
				s = 2.0 * fposmod(phase, 1.0) - 1.0
			"tri":
				s = 4.0 * absf(fposmod(phase, 1.0) - 0.5) - 1.0
			_:
				# filtered noise; f acts as the low-pass cutoff
				var a := clampf(f / RATE * TAU, 0.01, 1.0)
				lp += a * ((randf() * 2.0 - 1.0) - lp)
				s = lp * 2.5
		phase += f / RATE
		out[i] = clampf(s * env * vol, -1.0, 1.0)
	return out


func _stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _build_streams() -> void:
	streams["pop"] = _stream(_gen("sine", 700.0, 230.0, 0.09, 0.65))
	streams["click"] = streams["pop"]
	streams["Pistol"] = _stream(_gen("noise", 1400.0, 1400.0, 0.12, 0.7))
	streams["Shotgun"] = _stream(_gen("noise", 800.0, 800.0, 0.2, 0.9))
	streams["Auto Rifle"] = _stream(_gen("noise", 1400.0, 1400.0, 0.08, 0.5))
	streams["Plasma Cannon"] = _stream(_gen("saw", 1200.0, 150.0, 0.18, 0.3))
	streams["Bazooka"] = _stream(_gen("noise", 400.0, 40.0, 0.4, 1.0))
	streams["groan"] = _stream(_gen("saw", 90.0, 70.0, 0.35, 0.14))
	streams["boss"] = _stream(_gen("saw", 45.0, 30.0, 0.75, 0.4))
	streams["spawn"] = _stream(_gen("saw", 90.0, 45.0, 0.4, 0.22))
	streams["hit"] = _stream(_gen("tri", 160.0, 40.0, 0.08, 0.5))

	# wave-clear jingle
	var notes := [440.0, 554.37, 659.25, 880.0]
	var total := PackedFloat32Array()
	total.resize(int(RATE * 0.6))
	for idx in notes.size():
		var s := _gen("sine", notes[idx], notes[idx], 0.25, 0.25)
		var off := int(idx * 0.08 * RATE)
		for i in s.size():
			total[off + i] += s[i]
	streams["clear"] = _stream(total)

	for f in MENU_MELODY:
		var mk := "menu_%s" % str(f)
		if not streams.has(mk):
			streams[mk] = _stream(_gen("sine", f, f, 0.8, 0.4))
	for f in MENU_BASS:
		var bk := "menubass_%s" % str(f)
		if not streams.has(bk):
			streams[bk] = _stream(_gen("tri", f, f, 1.4, 0.5))

	for f in BGM_NOTES:
		var key := "bgm_%s" % str(f)
		if not streams.has(key):
			streams[key] = _stream(_gen("tri", f, f, 0.35, 0.45))


# ------------------------------------------------------------------ playback
func _free_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]


func play(sfx_name: String, vol_scale := 1.0, pitch := 1.0) -> void:
	if not streams.has(sfx_name):
		return
	var p := _free_player(sfx_players)
	p.stream = streams[sfx_name]
	p.volume_db = linear_to_db(maxf(0.0001, master_vol * sfx_vol * vol_scale))
	p.pitch_scale = pitch
	p.play()


func play_weapon(weapon_name: String) -> void:
	play(weapon_name)


func play_groan() -> void:
	play("groan", 1.0, randf_range(0.8, 1.25))


func start_bgm() -> void:
	bgm_step = 0
	if bgm_timer and bgm_timer.is_stopped():
		bgm_timer.start()


func stop_bgm() -> void:
	if bgm_timer:
		bgm_timer.stop()


func _on_bgm_tick() -> void:
	var f = BGM_NOTES[bgm_step % BGM_NOTES.size()]
	var p := _free_player(music_players)
	p.stream = streams["bgm_%s" % str(f)]
	p.volume_db = linear_to_db(maxf(0.0001, master_vol * music_vol))
	p.play()
	bgm_step += 1


func start_menu_music() -> void:
	if menu_timer and menu_timer.is_stopped():
		menu_step = 0
		menu_timer.start()


func stop_menu_music() -> void:
	if menu_timer:
		menu_timer.stop()


func _play_music(stream_name: String, vol_scale := 1.0) -> void:
	var p := _free_player(music_players)
	p.stream = streams[stream_name]
	p.volume_db = linear_to_db(maxf(0.0001, master_vol * music_vol * vol_scale))
	p.play()


func _on_menu_tick() -> void:
	_play_music("menu_%s" % str(MENU_MELODY[menu_step % MENU_MELODY.size()]))
	if menu_step % 4 == 0:
		_play_music("menubass_%s" % str(MENU_BASS[(menu_step / 4) % MENU_BASS.size()]), 0.9)
	menu_step += 1


func set_master(v: float) -> void:
	master_vol = v


func set_music(v: float) -> void:
	music_vol = v


func set_sfx(v: float) -> void:
	sfx_vol = v
