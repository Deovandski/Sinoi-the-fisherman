extends Control
## Fight-box test: try every fight-box mode at any difficulty.
##
## - A drop-down at the top picks the mode (data/fight_modes.json).
## - Under it, a difficulty slider (0 easy .. 10 hard); each mode remembers
##   its own level.
## - Back, the stats for this mode and level, and Copy (results to the
##   clipboard, to send back).
## - The fight box itself is a FightStage (scripts/fight/fight_stage.gd).
## Results are kept per mode and per level in the save (playtest.fight_modes).

const STAGE_TOP := 46.0
const DEFAULT_LEVEL := 5

var _entries: Array = []
var _index := 0
var _sessions := {}       # mode id -> {difficulty level -> FightSession}
var _levels := {}         # mode id -> difficulty level (0..10)

var _picker: OptionButton
var _slider: DifficultySlider
var _stats: Label
var _stage: FightStage


func _ready() -> void:
	theme = UiTheme.build()
	_entries = FightCatalog.entries()
	_load_results()
	tree_exiting.connect(_store_results)

	var bg := ColorRect.new()
	bg.color = Color("0d1b2a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_stage = FightStage.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.offset_top = STAGE_TOP
	_stage.changed.connect(_on_changed)
	_stage.ticked.connect(_on_ticked)
	add_child(_stage)

	var names := PackedStringArray()
	for e in _entries:
		names.append(tr(e.name))
	_picker = UiParts.picker(names, _select)
	_picker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_picker.offset_left = 2
	_picker.offset_right = -2
	_picker.offset_top = 2
	_picker.offset_bottom = 16
	add_child(_picker)

	_slider = DifficultySlider.new()
	_slider.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_slider.offset_left = 2
	_slider.offset_right = -2
	_slider.offset_top = 18
	_slider.offset_bottom = 30
	_slider.changed.connect(_on_difficulty)
	add_child(_slider)

	_stats = UiParts.status_row(self, 32, _copy_results)
	_select.call_deferred(0)


func _select(index: int) -> void:
	_store_results()
	_index = index
	_picker.select(index)
	var e: Dictionary = _entries[index]
	var level := _level()
	if not _sessions.has(e.id):
		_sessions[e.id] = {}
	if not _sessions[e.id].has(level):
		_sessions[e.id][level] = FightSession.new()
	_session().progress = FightSession.START
	_slider.set_level(level)
	var fingers := tr_n("%d finger", "%d fingers", int(e.fingers)) % int(e.fingers)
	_stage.play(FightCatalog.create(e.id, _stage.pad_side(), {}, level / float(DifficultySlider.MAX)),
		{"title": tr(e.name), "body": tr(e.hint), "footer": tr("Difficulty %d/10 - %s") % [level, fingers]})
	_refresh_meter()


func _session() -> FightSession:
	return _sessions[_entries[_index].id][_level()]


func _level() -> int:
	return int(_levels.get(_entries[_index].id, DEFAULT_LEVEL))


## The slider moved: restart the fight at the new level (each level's
## results are kept separately).
func _on_difficulty(level: int) -> void:
	if level == _level():
		return
	_levels[_entries[_index].id] = level
	_select(_index)


func _on_ticked(delta: float, judgement: Vector2) -> void:
	_session().tick(delta)
	_session().add_judgement(judgement)


func _on_changed(amount: float) -> void:
	match _session().add(amount):
		1:
			_stage.show_banner(tr("Caught! %.1f s") % _session().last_catch_time)
			_stage.play_sound("catch")
			_store_results()
		-1:
			_stage.show_banner(tr("It got away"))
			_stage.play_sound("miss")
			_store_results()
	_refresh_meter()


func _refresh_meter() -> void:
	_stage.meter = [_session().progress]
	_stage.meter_current = 0


func _process(_delta: float) -> void:
	if _sessions.is_empty():
		return
	var s := _session()
	var line := tr("Caught %d  Lost %d") % [s.catches, s.escapes]
	if s.catches > 0:
		line += "  %.1fs" % s.average_catch_time()
	if s.judged > 0.0:
		line += "  %d%%" % roundi(s.accuracy() * 100.0)
	_stats.text = line


# --- Results ------------------------------------------------------------------------

## Results live in the save (playtest.fight_modes), per mode and per level,
## so they add up over several sessions. "Reset save" on the title screen
## clears them.
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
	var lines: Array[String] = [ResultsText.header("fight-box test", _stage.sensor_available()),
		"mode | difficulty (0-10) | caught | lost | avg catch s | accuracy %"]
	for e in _entries:
		var by_level: Dictionary = _sessions.get(e.id, {})
		var keys := by_level.keys()
		keys.sort()
		for level in keys:
			var s: FightSession = by_level[level]
			if s.played():
				lines.append("%s | %d | %s" % [e.name, level, ResultsText.totals(s)])
	if lines.size() == 2:
		lines.append("(no modes played yet)")
	ResultsText.copy(lines)
	_stage.show_banner(tr("Results copied"))
