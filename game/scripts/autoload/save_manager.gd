extends Node
## Saves the game locally and moves saves in and out as JSON files.
##
## - Local save: user://save.json (IndexedDB in browsers, app storage on Android).
## - Export: browser download on the web; the system file picker on Android
##   and desktop, with a clipboard fallback.
## - Import: file picker on every platform, with a clipboard fallback.
##
## The JSON format is documented in docs/SAVE_FORMAT.md. Bump VERSION and add
## a step to _migrate() whenever the format changes.

signal changed
signal message(text: String)

const FORMAT := "sinoi-save"
const VERSION := 7
const MAX_IMPORT_BYTES := 1_000_000

var save_path := "user://save.json"
var data: Dictionary = {}

var _web_callback = null  # Keeps the JavaScript callback alive while the picker is open.


func _ready() -> void:
	load_local()


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

static func default_data() -> Dictionary:
	var now := Time.get_datetime_string_from_system(true)
	return {
		"format": FORMAT,
		"version": VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"created_at": now,
		"updated_at": now,
		"pearls": 0,
		"catches": [],
		# One entry per fish species caught (see Journal.record()).
		"journal": {},
		"settings": {
			"timing_forgiveness": 0,
			"left_handed": false,
		},
		# Pre-production playtests (see FightSession.to_dict()):
		# fight_modes: per mode, the chosen difficulty and totals per level;
		# fish: totals per fish from the fish test;
		# streak: catches in a row in the fish test, now and best.
		"playtest": {
			"fight_modes": {},
			"fish": {},
			"streak": {"current": 0, "best": 0},
		},
	}


func to_json() -> String:
	return JSON.stringify(data, "  ")


## Validates and applies a save. Returns {"ok": bool, "message": String}.
func apply_json(text: String) -> Dictionary:
	if text.length() > MAX_IMPORT_BYTES:
		return _fail("That file is too big to be a save.")
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("That file isn't valid save data (not JSON).")
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("That file isn't valid save data (not JSON).")
	if parsed.get("format", "") != FORMAT:
		return _fail("That JSON isn't a Sinoi the Fisherman save.")
	var version := int(parsed.get("version", 0))
	if version < 1:
		return _fail("That save has no version number.")
	if version > VERSION:
		return _fail("That save comes from a newer version of the game. Update the game first.")
	var migrated := _migrate(parsed, version)
	data = _merge_defaults(migrated, default_data())
	data["version"] = VERSION
	changed.emit()
	return {"ok": true, "message": "Save loaded."}


func _fail(text: String) -> Dictionary:
	return {"ok": false, "message": text}


## Upgrades older saves one version at a time.
func _migrate(save: Dictionary, from_version: int) -> Dictionary:
	var out := save.duplicate(true)
	if from_version < 2:
		# v2 adds the fight-box playtest results.
		out["playtest"] = {"fight_modes": {}}
	if from_version < 3:
		# v3 splits results by difficulty level. v2 results were played at the
		# fixed tuning, which is today's middle level (5).
		var modes: Variant = out.get("playtest", {}).get("fight_modes", {})
		var upgraded := {}
		if typeof(modes) == TYPE_DICTIONARY:
			for id in modes:
				if typeof(modes[id]) == TYPE_DICTIONARY:
					upgraded[id] = {"difficulty": 5, "levels": {"5": modes[id]}}
		out["playtest"] = {"fight_modes": upgraded}
	if from_version < 4:
		# v4 drops the "How hard?" ratings (the difficulty slider replaced
		# them) and adds fish-test results.
		var playtest: Dictionary = out.get("playtest", {}) if typeof(out.get("playtest")) == TYPE_DICTIONARY else {}
		var modes: Variant = playtest.get("fight_modes", {})
		if typeof(modes) == TYPE_DICTIONARY:
			for id in modes:
				var levels: Variant = modes[id].get("levels", {}) if typeof(modes[id]) == TYPE_DICTIONARY else {}
				if typeof(levels) == TYPE_DICTIONARY:
					for level in levels:
						if typeof(levels[level]) == TYPE_DICTIONARY:
							levels[level].erase("feel")
		playtest["fish"] = {}
		out["playtest"] = playtest
	if from_version < 5:
		# v5 adds the fish-test catch streak.
		out["playtest"]["streak"] = {"current": 0, "best": 0}
	if from_version < 6:
		# v6: catches record quality, size and the streak they were made on;
		# fish-test results keep each fish's best size and quality.
		var catches: Variant = out.get("catches", [])
		if typeof(catches) == TYPE_ARRAY:
			for c in catches:
				if typeof(c) == TYPE_DICTIONARY:
					c["quality"] = int(c.get("quality", 0))
					c["size_cm"] = float(c.get("size_cm", 0.0))
					c["streak"] = int(c.get("streak", 0))
		var fish: Variant = out["playtest"].get("fish", {})
		if typeof(fish) == TYPE_DICTIONARY:
			for id in fish:
				if typeof(fish[id]) == TYPE_DICTIONARY:
					fish[id]["best_size_cm"] = float(fish[id].get("best_size_cm", 0.0))
					fish[id]["best_quality"] = int(fish[id].get("best_quality", 0))
	if from_version < 7:
		# v7 adds the journal, built from the catch log so far.
		out["journal"] = Journal.rebuild(out.get("catches", []) if typeof(out.get("catches")) == TYPE_ARRAY else [])
	return out


## Fills in keys a save is missing and drops values of the wrong type.
static func _merge_defaults(save: Dictionary, defaults: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	for key in save.keys():
		if not out.has(key):
			out[key] = save[key]
		elif typeof(out[key]) == TYPE_DICTIONARY and typeof(save[key]) == TYPE_DICTIONARY:
			out[key] = _merge_defaults(save[key], out[key])
		elif _same_kind(out[key], save[key]):
			out[key] = save[key]
	return out


static func _same_kind(a, b) -> bool:
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numbers and typeof(b) in numbers:
		return true
	return typeof(a) == typeof(b)


# ---------------------------------------------------------------------------
# Local save
# ---------------------------------------------------------------------------

func save_local() -> bool:
	data["updated_at"] = Time.get_datetime_string_from_system(true)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s (error %d)" % [save_path, FileAccess.get_open_error()])
		return false
	file.store_string(to_json())
	file.close()
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
	return true


func load_local() -> void:
	if FileAccess.file_exists(save_path):
		var result := apply_json(FileAccess.get_file_as_string(save_path))
		if result.ok:
			return
		push_warning("Local save unreadable, starting fresh: %s" % result.message)
	data = default_data()
	changed.emit()


func reset() -> void:
	data = default_data()
	save_local()
	changed.emit()


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

func export_file_name() -> String:
	var stamp := Time.get_datetime_string_from_system(false).replace(":", "").replace("-", "").replace("T", "-")
	return "sinoi-save-%s.json" % stamp


## Call from a button press: browsers only allow downloads from user input.
func export_save() -> void:
	save_local()
	var text := to_json()
	var file_name := export_file_name()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")
		message.emit("Save downloaded as %s." % file_name)
	elif DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Export save", OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS),
			file_name, false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
			PackedStringArray(["*.json ; JSON save"]), _on_export_path_chosen.bind(text))
	else:
		_export_to_clipboard(text)


func _on_export_path_chosen(status: bool, paths: PackedStringArray, _filter: int, text: String) -> void:
	if not status or paths.is_empty():
		message.emit("Export cancelled.")
		return
	var file := FileAccess.open(paths[0], FileAccess.WRITE)
	if file == null:
		_export_to_clipboard(text)
		return
	file.store_string(text)
	file.close()
	message.emit("Save exported.")


func _export_to_clipboard(text: String) -> void:
	DisplayServer.clipboard_set(text)
	message.emit("Save copied to the clipboard. Paste it into a .json file to keep it.")


# ---------------------------------------------------------------------------
# Import
# ---------------------------------------------------------------------------

## Call from a button press: browsers only open file pickers from user input.
func import_save() -> void:
	if OS.has_feature("web"):
		_web_pick_file()
	elif DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Import save", OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS),
			"", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			PackedStringArray(["*.json ; JSON save"]), _on_import_path_chosen)
	else:
		import_from_clipboard()


func _on_import_path_chosen(status: bool, paths: PackedStringArray, _filter: int) -> void:
	if not status or paths.is_empty():
		message.emit("Import cancelled.")
		return
	var file := FileAccess.open(paths[0], FileAccess.READ)
	if file == null:
		message.emit("Couldn't open that file. Try copying the save text and using Paste save.")
		return
	_finish_import(file.get_as_text())


func import_from_clipboard() -> void:
	_finish_import(DisplayServer.clipboard_get())


func _finish_import(text: String) -> void:
	var result := apply_json(text)
	if result.ok:
		save_local()
	message.emit(result.message)


func _web_pick_file() -> void:
	_web_callback = JavaScriptBridge.create_callback(_on_web_file_text)
	var window = JavaScriptBridge.get_interface("window")
	window.sinoiReceiveSave = _web_callback
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json,application/json';
			input.onchange = function (event) {
				var file = event.target.files && event.target.files[0];
				if (!file) { return; }
				var reader = new FileReader();
				reader.onload = function () { window.sinoiReceiveSave(String(reader.result)); };
				reader.readAsText(file);
			};
			input.click();
		})();
	""", true)


func _on_web_file_text(args: Array) -> void:
	if args.is_empty():
		return
	_finish_import(str(args[0]))
