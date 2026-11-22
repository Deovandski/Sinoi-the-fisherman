extends Control
## Fight-box touch test: a playground for the fight-box modes.
##
## Layout (decided in docs/white-paper/02-design-direction.md):
## - a carousel at the very top picks the mode (data/fight_modes.json);
## - under it, a difficulty slider (0 easy .. 10 hard) sets how hard that
##   mode plays; each mode remembers its own level (later, each fish sets it);
## - the shadow pad (top) shows the full picture and ghost fingers;
## - the real pad (bottom) is where fingers go, with light outlines only;
## - the catch meter and the mode's live cue sit between them;
## - under the real pad, testers rate how hard a mode felt (1-5) and copy
##   their results to send back.
## The Lost Ref mode takes the top (reference) box away for a while: the
## bottom box goes out and the player plays in the top box instead.
##
## Modes live in scripts/fight/modes/; this script only routes input, runs
## the meter (FightSession) and draws the frame around them.

const INTRO_TIME := 3.0
const BANNER_TIME := 1.2
const FINGER_COLORS := [Color("ffd166"), Color("06d6a0"), Color("ef476f"), Color("118ab2"), Color("ffffff")]
const PAD_TOP := 46.0
const DEFAULT_LEVEL := 5
const MIDDLE := 22.0
const BOTTOM_ROW := 16.0

var _entries: Array = []
var _index := 0
var _mode: FightMode
var _sessions := {}       # mode id -> {difficulty level -> FightSession}
var _levels := {}         # mode id -> difficulty level (0..10)
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
var _slider: DifficultySlider
var _stats: Label
var _top_view: Control
var _bottom_view: Control
var _overlay: Control
var _feel_row: HBoxContainer
var _feel_buttons: Array[Button] = []


func _ready() -> void:
	theme = UiTheme.build()
	_entries = FightCatalog.entries()
	_load_results()
	tree_exiting.connect(_store_results)
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
	_top_view = _make_view(true)
	_bottom_view = _make_view(false)

	_carousel = ModeCarousel.new()
	var names := PackedStringArray()
	for e in _entries:
		names.append(e.name)
	_carousel.set_names(names)
	_carousel.selected.connect(_select)
	add_child(_carousel)

	_slider = DifficultySlider.new()
	_slider.changed.connect(_on_difficulty)
	add_child(_slider)

	var row := HBoxContainer.new()
	row.position = Vector2(2, 31)
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
	_slider.position = Vector2(2, 17)
	_slider.size = Vector2(size.x - 4.0, 12)
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
	return _top_rect() if _pads() == FightMode.Pads.TOP_ONLY else _bottom_rect()


func _pads() -> FightMode.Pads:
	return _mode.pads() if _mode != null else FightMode.Pads.NORMAL


func _place_views() -> void:
	_top_view.position = _top_rect().position
	_top_view.size = _top_rect().size
	_bottom_view.position = _bottom_rect().position
	_bottom_view.size = _bottom_rect().size


# --- Modes -----------------------------------------------------------------------

func _select(index: int) -> void:
	if _mode != null:
		_store_results()
	_index = index
	var e: Dictionary = _entries[index]
	var level := _level()
	_mode = FightCatalog.create(e.id, _side, {}, level / float(DifficultySlider.MAX))
	if not _sessions.has(e.id):
		_sessions[e.id] = {}
	if not _sessions[e.id].has(level):
		_sessions[e.id][level] = FightSession.new()
	_session().progress = FightSession.START
	_slider.set_level(level)
	_pad_touches.clear()
	_intro_left = INTRO_TIME
	_banner_left = 0.0
	_carousel.select(index, false)
	for i in _feel_buttons.size():
		_feel_buttons[i].set_pressed_no_signal(_session().feel == i + 1)
	_place_views()


func _session() -> FightSession:
	return _sessions[_entries[_index].id][_level()]


func _level() -> int:
	return int(_levels.get(_entries[_index].id, DEFAULT_LEVEL))


## The slider moved: restart the fight at the new level (the old level's
## results are kept separately).
func _on_difficulty(level: int) -> void:
	if level == _level():
		return
	_store_results()
	_levels[_entries[_index].id] = level
	_select(_index)
	_store_results()


func _process(delta: float) -> void:
	if _mode == null:
		return
	var was_active := _active_rect()
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
	if _active_rect() != was_active:
		_release_pad_touches()
	_stats.text = _stats_text()
	queue_redraw()
	_top_view.queue_redraw()
	_bottom_view.queue_redraw()
	_overlay.queue_redraw()


func _apply(change: float) -> void:
	if change == 0.0:
		return
	match _session().add(change):
		1:
			_show_banner("Caught! %.1f s" % _session().last_catch_time)
			_play("catch")
			_store_results()
		-1:
			_show_banner("It got away")
			_play("miss")
			_store_results()


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
		var to: Vector2 = (make_input_local(event) as InputEventScreenDrag).position
		_touches[event.index] = to
		# A finger slid into the box being played (Lost Ref sends players
		# between boxes) starts counting without having to lift first.
		if not _pad_touches.has(event.index) and _intro_left <= 0.0 and _active_rect().has_point(to) \
				and _pad_touches.size() < _mode.max_fingers():
			_pad_touches[event.index] = true
			_apply(_mode.touch(event.index, _to_pad(to), true))


## Screen position -> pad space of the box being played.
func _to_pad(at: Vector2) -> Vector2:
	return at - _active_rect().position


## When play moves to the other box, fingers in the old box stop counting:
## the player lifts and puts them down in the new box.
func _release_pad_touches() -> void:
	for index in _pad_touches.keys():
		if _touches.has(index):
			_apply(_mode.touch(index, _to_pad(_touches[index]), false))
	_pad_touches.clear()


# --- Feel ratings and results ----------------------------------------------------------

func _on_feel(n: int) -> void:
	_session().feel = n
	for i in _feel_buttons.size():
		_feel_buttons[i].set_pressed_no_signal(i + 1 == n)
	_store_results()


## Results and ratings live in the save (playtest.fight_modes, format v3),
## per mode and per difficulty level, so they add up over several sessions.
## "Reset save" on the title screen clears them.
func _load_results() -> void:
	var saved: Dictionary = SaveManager.data.get("playtest", {}).get("fight_modes", {})
	for id in saved:
		var entry: Variant = saved[id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_levels[id] = clampi(int(entry.get("difficulty", DEFAULT_LEVEL)), 0, DifficultySlider.MAX)
		_sessions[id] = {}
		var levels: Variant = entry.get("levels", {})
		if typeof(levels) == TYPE_DICTIONARY:
			for key in levels:
				if typeof(levels[key]) == TYPE_DICTIONARY and str(key).is_valid_int():
					_sessions[id][clampi(int(key), 0, DifficultySlider.MAX)] = FightSession.from_dict(levels[key])


func _store_results() -> void:
	if not SaveManager.data.has("playtest"):
		return
	var out := {}
	for id in _sessions:
		var levels := {}
		for level in _sessions[id]:
			if _sessions[id][level].played():
				levels[str(level)] = _sessions[id][level].to_dict()
		if not levels.is_empty() or _levels.has(id):
			out[id] = {"difficulty": int(_levels.get(id, DEFAULT_LEVEL)), "levels": levels}
	SaveManager.data.playtest.fight_modes = out
	SaveManager.save_local()


func _copy_results() -> void:
	var lines: Array[String] = []
	lines.append("Sinoi the Fisherman fight-box test, build %s, %s, screen %dx%d, motion sensor %s" % [
		ProjectSettings.get_setting("application/config/version"), OS.get_name(),
		DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y,
		"yes" if _sensor.available() else "no"])
	lines.append("mode | difficulty (0-10) | caught | lost | avg catch s | accuracy % | felt (1-5)")
	var any := false
	for e in _entries:
		var by_level: Dictionary = _sessions.get(e.id, {})
		var keys := by_level.keys()
		keys.sort()
		for level in keys:
			var s: FightSession = by_level[level]
			if not s.played():
				continue
			any = true
			lines.append("%s | %d | %d | %d | %s | %d | %s" % [e.name, level, s.catches, s.escapes,
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


func _draw_view(view: Control, top: bool) -> void:
	var rect := Rect2(Vector2.ZERO, view.size)
	var pads := _pads()
	var blink := int(Time.get_ticks_msec() / 150) % 2 == 0
	view.draw_rect(rect, Color("16324a") if top else Color("102536"))
	var out := not top and pads == FightMode.Pads.TOP_ONLY      # bottom box red, arrow up
	var flashing := top and pads == FightMode.Pads.BACK_DOWN    # top box flashes yellow
	if _mode != null and not out and not flashing:
		# The top box always shows the full picture (it's the reference, or the
		# only box during TOP_ONLY); the bottom box shows light outlines.
		_mode.draw_pad(view, top)
	if not out:
		_draw_fingers(view, rect, top)
	if out or (not top and pads == FightMode.Pads.BACK_DOWN):
		view.draw_rect(rect, Color(0.94, 0.28, 0.44, 0.55 if out else 0.3))
		_draw_arrow(view, rect.get_center(), -1.0 if out else 1.0)
	if flashing:
		view.draw_rect(rect, Color(1, 0.82, 0.4, 0.45 if blink else 0.15))
	var border := Color("6fa3c0") if top else Color("3d6680")
	var width := 1.0
	if pads == FightMode.Pads.WARN_UP:
		# Both boxes pulse before the bottom one goes out.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 3.0)
		border = Color("3d6680").lerp(Color("ef476f"), pulse)
		width = 1.0 + roundf(pulse * 2.0)
		view.draw_rect(rect, Color(1, 1, 1, 0.08 * pulse))
	elif out:
		border = Color("ef476f")
	elif flashing:
		border = Color("ffd166")
	view.draw_rect(rect.grow(-(width - 1.0) / 2.0), border, false, width)


## Ghost fingers on the reference box, real dots on the box being played.
func _draw_fingers(view: Control, rect: Rect2, top: bool) -> void:
	var playing := (top and _pads() == FightMode.Pads.TOP_ONLY) or (not top and _pads() != FightMode.Pads.TOP_ONLY)
	var i := 0
	for index in _touches:
		var counted := _pad_touches.has(index)
		if not playing and not counted:
			continue
		var color: Color = FINGER_COLORS[mini(i, FINGER_COLORS.size() - 1)] if counted else Color(1, 1, 1, 0.35)
		var at: Vector2 = _to_pad(_touches[index]) if counted or not playing else _touches[index] - view.position
		if rect.grow(6.0).has_point(at):
			view.draw_circle(at, 5.0 if playing else 4.0, color if playing else Color(color, 0.8))
		if counted:
			i += 1


## A big arrow telling the player which box to move to (dir -1 up, 1 down).
func _draw_arrow(view: Control, at: Vector2, dir: float) -> void:
	var s := _side * 0.16
	var bob := sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.0) * 3.0 * dir
	var tip := at + Vector2(0, dir * s * 1.1 + bob)
	var base_y := tip.y - dir * s
	var color := Color("eef6fa")
	view.draw_colored_polygon(PackedVector2Array([tip, Vector2(at.x - s, base_y), Vector2(at.x + s, base_y)]), color)
	var tail_y := base_y - dir * s * 1.2
	view.draw_rect(Rect2(at.x - s * 0.25, minf(base_y, tail_y), s * 0.5, absf(tail_y - base_y)), color)


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
		FightMode.text(_overlay, Vector2(card.get_center().x, card.end.y - 22.0), "Difficulty %d/10 - %s" % [_level(), fingers], Color("9fc3d6"))
		var start := "Touch the bottom box to start" if not _mode.uses_motion() else "Starting in %d..." % ceili(_intro_left)
		FightMode.text(_overlay, Vector2(card.get_center().x, card.end.y - 10.0), start, Color("f3e3b3"))
	elif _banner_left > 0.0:
		var strip := Rect2(card.position.x, card.get_center().y - 9.0, card.size.x, 18.0)
		_overlay.draw_rect(strip, Color(0.04, 0.09, 0.14, 0.85))
		FightMode.text(_overlay, strip.get_center(), _banner, Color("ffd166"), 10)
