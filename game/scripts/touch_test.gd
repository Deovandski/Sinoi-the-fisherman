extends Control
## Fight-box touch test: a playground for the fight-box modes.
##
## Layout (decided in docs/white-paper/02-design-direction.md):
## - a carousel at the very top picks the mode (data/fight_modes.json, in
##   predicted order from easiest to hardest);
## - the shadow pad (top) shows the full picture and ghost fingers;
## - the real pad (bottom) is where fingers go, with light outlines only;
## - the catch meter and the mode's live cue sit between them;
## - under the real pad, testers rate how hard a mode felt (1-5) and copy
##   their results to send back.
## The Flip mode swaps the pads and turns them upside down.
##
## Modes live in scripts/fight/modes/; this script only routes input, runs
## the meter (FightSession) and draws the frame around them.

const INTRO_TIME := 3.0
const BANNER_TIME := 1.2
const FINGER_COLORS := [Color("ffd166"), Color("06d6a0"), Color("ef476f"), Color("118ab2"), Color("ffffff")]
const PAD_TOP := 34.0
const MIDDLE := 22.0
const BOTTOM_ROW := 16.0

var _entries: Array = []
var _index := 0
var _mode: FightMode
var _sessions := {}       # mode id -> FightSession
var _touches := {}        # touch index -> position in this control
var _pad_touches := {}    # touch indexes that started in the real pad (in order)
var _intro_left := 0.0
var _banner := ""
var _banner_left := 0.0
var _sensor := MotionSensor.new()
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _side := 120.0

var _carousel: ModeCarousel
var _stats: Label
var _shadow_view: Control
var _active_view: Control
var _overlay: Control
var _feel_row: HBoxContainer
var _feel_buttons: Array[Button] = []


func _ready() -> void:
	theme = UiTheme.build()
	_entries = FightCatalog.entries()
	_sounds = Blip.build_all()
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		_players.append(player)
	_build_ui()
	resized.connect(_layout)
	_layout()
	_select(0)


# --- UI ------------------------------------------------------------------------

func _build_ui() -> void:
	_shadow_view = _make_view(true)
	_active_view = _make_view(false)

	_carousel = ModeCarousel.new()
	var names := PackedStringArray()
	for e in _entries:
		names.append(e.name)
	_carousel.set_names(names)
	_carousel.selected.connect(_select)
	add_child(_carousel)

	var row := HBoxContainer.new()
	row.position = Vector2(2, 18)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	row.add_child(_small_button("< Back", func(): get_tree().change_scene_to_file("res://scenes/main.tscn")))
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 7)
	_stats.add_theme_color_override("font_color", Color("c9dbe4"))
	row.add_child(_stats)

	_feel_row = HBoxContainer.new()
	_feel_row.add_theme_constant_override("separation", 2)
	add_child(_feel_row)
	var feel_label := Label.new()
	feel_label.text = "How hard?"
	feel_label.add_theme_font_size_override("font_size", 7)
	feel_label.add_theme_color_override("font_color", Color("9fc3d6"))
	_feel_row.add_child(feel_label)
	for n in range(1, 6):
		var b := _small_button(str(n), _on_feel.bind(n))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(13, 13)
		_feel_row.add_child(b)
		_feel_buttons.append(b)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(4, 0)
	_feel_row.add_child(spacer)
	_feel_row.add_child(_small_button("Copy", _copy_results))

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _make_view(shadow: bool) -> Control:
	var view := Control.new()
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view.bind(view, shadow))
	add_child(view)
	return view


func _small_button(label: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.add_theme_font_size_override("font_size", 7)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _layout() -> void:
	_side = floorf(minf(size.x - 16.0, (size.y - PAD_TOP - MIDDLE - BOTTOM_ROW - 2.0) / 2.0))
	_carousel.position = Vector2(2, 2)
	_carousel.size = Vector2(size.x - 4.0, 14)
	_feel_row.position = Vector2(_top_rect().position.x, _bottom_rect().end.y + 3.0)
	_feel_row.size = Vector2(_side, 13)
	if _mode != null:
		_mode.side = _side
	_place_views()


func _top_rect() -> Rect2:
	return Rect2(Vector2(floorf((size.x - _side) / 2.0), PAD_TOP), Vector2(_side, _side))


func _bottom_rect() -> Rect2:
	return Rect2(Vector2(floorf((size.x - _side) / 2.0), PAD_TOP + _side + MIDDLE), Vector2(_side, _side))


func _active_rect() -> Rect2:
	return _top_rect() if _flipped() else _bottom_rect()


func _shadow_rect() -> Rect2:
	return _bottom_rect() if _flipped() else _top_rect()


func _flipped() -> bool:
	return _mode != null and _mode.is_flipped()


func _place_views() -> void:
	for pair in [[_shadow_view, _shadow_rect()], [_active_view, _active_rect()]]:
		var view: Control = pair[0]
		var rect: Rect2 = pair[1]
		view.position = rect.position
		view.size = rect.size
		view.pivot_offset = rect.size / 2.0
		view.rotation = PI if _flipped() else 0.0


# --- Modes -----------------------------------------------------------------------

func _select(index: int) -> void:
	_index = index
	var e: Dictionary = _entries[index]
	_mode = FightCatalog.create(e.id, _side)
	if not _sessions.has(e.id):
		_sessions[e.id] = FightSession.new()
	_session().progress = FightSession.START
	_pad_touches.clear()
	_intro_left = INTRO_TIME
	_banner_left = 0.0
	_carousel.select(index, false)
	for i in _feel_buttons.size():
		_feel_buttons[i].set_pressed_no_signal(_session().feel == i + 1)
	_place_views()


func _session() -> FightSession:
	return _sessions[_entries[_index].id]


func _process(delta: float) -> void:
	if _mode == null:
		return
	var was_flipped := _flipped()
	if _mode.uses_motion():
		_mode.motion(_sensor.read(), _sensor.available())
	if _intro_left > 0.0:
		_intro_left -= delta
	else:
		var fingers := {}
		for i in _pad_touches:
			if _touches.has(i):
				fingers[i] = _to_pad(_touches[i])
		_session().tick(delta)
		_apply(_mode.step(delta, fingers))
		_session().add_judgement(_mode.take_judgement())
	_banner_left -= delta
	for sound in _mode.sounds:
		_play(sound)
	_mode.sounds.clear()
	if _flipped() != was_flipped:
		_place_views()
	_stats.text = _stats_text()
	queue_redraw()
	_shadow_view.queue_redraw()
	_active_view.queue_redraw()
	_overlay.queue_redraw()


func _apply(change: float) -> void:
	if change == 0.0:
		return
	match _session().add(change):
		1:
			_show_banner("Caught! %.1f s" % _session().catch_times[-1])
			_play("catch")
		-1:
			_show_banner("It got away")
			_play("miss")


func _show_banner(text: String) -> void:
	_banner = text
	_banner_left = BANNER_TIME


func _stats_text() -> String:
	var s := _session()
	var line := "Caught %d  Lost %d" % [s.catches, s.escapes]
	if s.catches > 0:
		line += "  %.1fs" % s.average_catch_time()
	if s.judged > 0.0:
		line += "  %d%%" % roundi(s.accuracy() * 100.0)
	return line


func _play(sound: String) -> void:
	if not _sounds.has(sound):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _sounds[sound]
	player.play()


# --- Input -------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var at: Vector2 = (make_input_local(event) as InputEventScreenTouch).position
		if event.pressed:
			_touches[event.index] = at
			if _active_rect().grow(4.0).has_point(at) and _pad_touches.size() < _mode.max_fingers():
				_pad_touches[event.index] = true
				_intro_left = 0.0
				_apply(_mode.touch(event.index, _to_pad(at), true))
		else:
			_touches[event.index] = at
			if _pad_touches.has(event.index):
				_pad_touches.erase(event.index)
				_apply(_mode.touch(event.index, _to_pad(at), false))
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		_touches[event.index] = (make_input_local(event) as InputEventScreenDrag).position


## Screen position -> pad space, undoing the Flip mode's half turn.
func _to_pad(at: Vector2) -> Vector2:
	var local := at - _active_rect().position
	return Vector2(_side, _side) - local if _flipped() else local


# --- Feel ratings and results ----------------------------------------------------------

func _on_feel(n: int) -> void:
	_session().feel = n
	for i in _feel_buttons.size():
		_feel_buttons[i].set_pressed_no_signal(i + 1 == n)


func _copy_results() -> void:
	var lines: Array[String] = []
	lines.append("Sinoi the Fisherman fight-box test, build %s, %s, screen %dx%d, motion sensor %s" % [
		ProjectSettings.get_setting("application/config/version"), OS.get_name(),
		DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y,
		"yes" if _sensor.available() else "no"])
	lines.append("mode | guess | caught | lost | avg catch s | accuracy % | felt (1-5)")
	var any := false
	for e in _entries:
		var s: FightSession = _sessions.get(e.id)
		if s == null or not s.played():
			continue
		any = true
		lines.append("%s | %d | %d | %d | %s | %d | %s" % [e.name, int(e.guess), s.catches, s.escapes,
			("%.1f" % s.average_catch_time()) if s.catches > 0 else "-",
			roundi(s.accuracy() * 100.0), str(s.feel) if s.feel > 0 else "-"])
	if not any:
		lines.append("(no modes played yet)")
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	print(text)
	_show_banner("Results copied")


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d1b2a"))
	var top := _top_rect()
	var meter := Rect2(Vector2(top.position.x, top.end.y + 4.0), Vector2(_side, 5.0))
	draw_rect(meter, Color("23415a"))
	draw_rect(Rect2(meter.position, Vector2(meter.size.x * _session().progress, meter.size.y)), Color("06d6a0"))
	draw_rect(Rect2(meter.position + Vector2(meter.size.x * FightSession.START, 0), Vector2(1, meter.size.y)), Color(1, 1, 1, 0.3))
	draw_rect(meter, Color("6fa3c0"), false, 1.0)
	if _mode != null and _intro_left <= 0.0:
		FightMode.text(self, Vector2(size.x / 2.0, meter.end.y + 7.0), _mode.cue, Color("f3e3b3"), 8)


func _draw_view(view: Control, shadow: bool) -> void:
	var rect := Rect2(Vector2.ZERO, view.size)
	view.draw_rect(rect, Color("16324a") if shadow else Color("102536"))
	if _mode != null:
		_mode.draw_pad(view, shadow)
	# Fingers: real dots on the real pad, ghosts on the shadow.
	var i := 0
	for index in _touches:
		var counted := _pad_touches.has(index)
		if shadow and not counted:
			continue
		var color: Color = FINGER_COLORS[mini(i, FINGER_COLORS.size() - 1)] if counted else Color(1, 1, 1, 0.35)
		var at := _to_pad(_touches[index])
		if rect.grow(6.0).has_point(at):
			view.draw_circle(at, 4.0 if shadow else 5.0, Color(color, 0.8) if shadow else color)
		if counted:
			i += 1
	var border := Color("6fa3c0") if shadow else Color("3d6680")
	if _mode != null and _mode.flip_warning() >= 0.0 and int(Time.get_ticks_msec() / 150) % 2 == 0:
		border = Color("ef476f")
	view.draw_rect(rect, border, false, 1.0)


func _draw_overlay() -> void:
	if _mode == null:
		return
	var card := _top_rect().grow(-6.0)
	if _intro_left > 0.0:
		var e: Dictionary = _entries[_index]
		_overlay.draw_rect(card, Color(0.04, 0.09, 0.14, 0.92))
		_overlay.draw_rect(card, Color("ffd166"), false, 1.0)
		var font := ThemeDB.fallback_font
		FightMode.text(_overlay, Vector2(card.get_center().x, card.position.y + 10.0), e.name, Color("ffd166"), 10)
		_overlay.draw_multiline_string(font, card.position + Vector2(6, 26), e.hint, HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 12.0, 7, -1, Color("eef6fa"))
		var fingers := "1 finger" if int(e.fingers) == 1 else "%d fingers" % int(e.fingers)
		FightMode.text(_overlay, Vector2(card.get_center().x, card.end.y - 22.0), "Difficulty guess %d/5 - %s" % [int(e.guess), fingers], Color("9fc3d6"))
		var start := "Touch the bottom box to start" if not _mode.uses_motion() else "Starting in %d..." % ceili(_intro_left)
		FightMode.text(_overlay, Vector2(card.get_center().x, card.end.y - 10.0), start, Color("f3e3b3"))
	elif _banner_left > 0.0:
		var strip := Rect2(card.position.x, card.get_center().y - 9.0, card.size.x, 18.0)
		_overlay.draw_rect(strip, Color(0.04, 0.09, 0.14, 0.85))
		FightMode.text(_overlay, strip.get_center(), _banner, Color("ffd166"), 10)
