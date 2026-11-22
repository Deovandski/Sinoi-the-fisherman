extends Control
## Fish test: fight any fish in the game (data/fish.json) from a drop-down.
##
## Each fish fights in sections: the meter has one segment per section, and
## each section plays one fight-box mode whose difficulty climbs through the
## fish's range as the segment fills (scripts/fight/fish_fight.gd). There's
## no difficulty slider: difficulty is set per fish, in the data.
## A catch adds the fish and its pearls to the save, like the old Cast
## placeholder did; results per fish are kept in the save (playtest.fish).
## A strong section hands the next one a head start, and consecutive catches
## build a streak (kept across fish, so it can be carried to harder ones).

const STAGE_TOP := 33.0

var _entries: Array = []
var _index := 0
var _fight: FishFight
var _sessions := {}       # fish id -> FightSession (totals only)
var _streak := 0          # catches in a row, across fish
var _best_streak := 0
var _rng := RandomNumberGenerator.new()

var _picker: OptionButton
var _stats: Label
var _stage: FightStage


func _ready() -> void:
	theme = UiTheme.build()
	_rng.randomize()
	_entries = FishCatalog.entries()
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
		var count: int = e.get("sections", []).size()
		names.append("%s  (%d section%s)" % [e.name, count, "" if count == 1 else "s"])
	_picker = UiParts.picker(names, _select)
	_picker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_picker.offset_left = 2
	_picker.offset_right = -2
	_picker.offset_top = 2
	_picker.offset_bottom = 16
	add_child(_picker)

	_stats = UiParts.status_row(self, 19, _copy_results)
	_select.call_deferred(0)


func _select(index: int) -> void:
	_store_results()
	_index = index
	_picker.select(index)
	var e: Dictionary = _entries[index]
	if not _sessions.has(e.id):
		_sessions[e.id] = FightSession.new()
	_fight = FishFight.new(e, _stage.pad_side())
	var count := _fight.section_count()
	_stage.play(_fight.make_mode(_stage.pad_side()), {
		"title": e.name,
		"body": "%s\n\n%s" % [e.get("description", ""), _fight.sections_summary()],
		"footer": "%d section%s - %s - %d-%d pearls" % [count, "" if count == 1 else "s", e.get("curve", "climb"), int(e.pearls[0]), int(e.pearls[1])],
	})
	_refresh_meter()


func _session() -> FightSession:
	return _sessions[_entries[_index].id]


func _on_ticked(delta: float, judgement: Vector2) -> void:
	_session().tick(delta)
	_session().add_judgement(judgement)
	_fight.add_judgement(judgement)
	# Difficulty follows the fish's curve as the segment fills.
	if _stage.mode != null:
		_stage.mode.difficulty = _fight.difficulty()


func _on_changed(amount: float) -> void:
	match _fight.add(amount):
		FishFight.Result.SECTION_DONE:
			var name: String = FightCatalog.entry(_fight.section_mode_id()).get("name", "")
			_stage.play(_fight.make_mode(_stage.pad_side()))
			var title := "Section %d/%d: %s" % [_fight.section + 1, _fight.section_count(), name]
			if _fight.last_carry > 0.005:
				title += "\nStrong finish! Head start +%d%%" % roundi(_fight.last_carry * 100.0)
			_stage.show_banner(title)
			_stage.play_sound("tock")
		FishFight.Result.CAUGHT:
			_session().record_catch()
			var pearls := _award()
			_streak += 1
			_best_streak = maxi(_best_streak, _streak)
			_stage.show_banner("Caught %s! +%d pearls\nStreak %d (best %d)" % [_fight.fish.name, pearls, _streak, _best_streak])
			_stage.play_sound("catch")
			_restart()
		FishFight.Result.ESCAPED:
			_session().record_escape()
			var lost := "\nStreak of %d lost" % _streak if _streak > 1 else ""
			_streak = 0
			_stage.show_banner("%s got away%s" % [_fight.fish.name, lost])
			_stage.play_sound("miss")
			_restart()
	_refresh_meter()


func _restart() -> void:
	_fight.restart()
	_stage.play(_fight.make_mode(_stage.pad_side()))
	_store_results()


## Adds the catch and its pearls to the save, as the old Cast button did.
func _award() -> int:
	var fish := _fight.fish
	var pearls := _rng.randi_range(int(fish.pearls[0]), int(fish.pearls[1]))
	SaveManager.data.pearls = int(SaveManager.data.pearls) + pearls
	SaveManager.data.catches.append({
		"fish": fish.id,
		"pearls": pearls,
		"caught_at": Time.get_datetime_string_from_system(true),
	})
	return pearls


func _refresh_meter() -> void:
	_stage.meter = _fight.fills.duplicate()
	_stage.meter_current = _fight.section
	_stage.meter_start = FishFight.START if _fight.section == 0 else 0.0


func _process(_delta: float) -> void:
	if _fight == null:
		return
	var s := _session()
	var line := "Won %d Lost %d Streak %d Lv %.1f" % [s.catches, s.escapes, _streak, _fight.difficulty() * 10.0]
	_stats.text = line


# --- Results ------------------------------------------------------------------------

## Results per fish live in the save (playtest.fish); "Reset save" on the
## title screen clears them.
func _load_results() -> void:
	var streak: Variant = SaveManager.data.get("playtest", {}).get("streak", {})
	if typeof(streak) == TYPE_DICTIONARY:
		_streak = maxi(int(streak.get("current", 0)), 0)
		_best_streak = maxi(int(streak.get("best", 0)), _streak)
	var saved: Dictionary = SaveManager.data.get("playtest", {}).get("fish", {})
	for id in saved:
		if typeof(saved[id]) == TYPE_DICTIONARY:
			_sessions[id] = FightSession.from_dict(saved[id])


func _store_results() -> void:
	if not SaveManager.data.has("playtest"):
		return
	var out := {}
	for id in _sessions:
		if _sessions[id].played():
			out[id] = _sessions[id].to_dict()
	SaveManager.data.playtest["fish"] = out
	SaveManager.data.playtest["streak"] = {"current": _streak, "best": _best_streak}
	SaveManager.save_local()


func _copy_results() -> void:
	var lines: Array[String] = [ResultsText.header("fish test", _stage.sensor_available()),
		"streak: %d now, best %d" % [_streak, _best_streak],
		"fish | sections | caught | lost | avg catch s | accuracy %"]
	for e in _entries:
		var s: FightSession = _sessions.get(e.id)
		if s != null and s.played():
			lines.append("%s | %s (%s) | %s" % [e.name, FishFight.new(e, 120.0).sections_summary(), e.get("curve", "climb"), ResultsText.totals(s)])
	if lines.size() == 3:
		lines.append("(no fish fought yet)")
	ResultsText.copy(lines)
	_stage.show_banner("Results copied")
