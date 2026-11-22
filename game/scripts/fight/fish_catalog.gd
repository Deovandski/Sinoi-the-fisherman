class_name FishCatalog
extends RefCounted
## Reads data/fish.json: every fish, its reward and its fight sections.

const PATH := "res://data/fish.json"

static var _entries: Array = []
static var _rules: Dictionary = {}


## Rules for every fish fight (start fill, carry-over), from "rules".
static func rules() -> Dictionary:
	entries()
	return _rules


static func entries() -> Array:
	if _entries.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("FishCatalog: can't open %s" % PATH)
			return []
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("fish"):
			_entries = parsed.fish
			_rules = parsed.get("rules", {})
		else:
			push_error("FishCatalog: %s has no 'fish' list" % PATH)
	return _entries


static func entry(id: String) -> Dictionary:
	for e in entries():
		if e.id == id:
			return e
	return {}
