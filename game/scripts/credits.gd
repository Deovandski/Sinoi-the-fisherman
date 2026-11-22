class_name Credits
extends RefCounted
## The credits, links and one-line description, from data/credits.json (the
## one source shared with the website; see CLAUDE.md, "One source").

const PATH := "res://data/credits.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = parsed
		else:
			push_error("Credits: can't read %s" % PATH)
	return _data


static func support_text() -> String:
	return str(data().get("support_text", ""))


## A link by name: "amazon", "world_lore" or "series".
static func link(link_name: String) -> String:
	return str(data().get("links", {}).get(link_name, ""))
