class_name FightCatalog
extends RefCounted
## Reads data/fight_modes.json and builds mode objects by id.

const PATH := "res://data/fight_modes.json"

static var _entries: Array = []


static func entries() -> Array:
	if _entries.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("FightCatalog: can't open %s" % PATH)
			return []
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("modes"):
			_entries = parsed.modes
		else:
			push_error("FightCatalog: %s has no 'modes' list" % PATH)
	return _entries


static func entry(id: String) -> Dictionary:
	for e in entries():
		if e.id == id:
			return e
	return {}


## Builds and sets up the mode `id` for a pad of `side` pixels. `overrides`
## replace tuning values (tests use it to fix the random seed).
static func create(id: String, side: float, overrides := {}) -> FightMode:
	var e := entry(id)
	if e.is_empty():
		push_error("FightCatalog: unknown mode '%s'" % id)
		return null
	var mode: FightMode = load(e.script).new()
	var tuning: Dictionary = e.get("tuning", {}).duplicate()
	tuning.merge(overrides, true)
	mode.setup(id, tuning, side)
	return mode
