extends SceneTree
## Headless tests for SaveManager. Run from the repo root:
##   godot --headless --path game -s res://tests/test_save_manager.gd
## Exits with code 1 if any check fails (CI relies on this).

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")

var _failures := 0


func _init() -> void:
	var sm: Node = SaveManagerScript.new()
	sm.save_path = "user://test_save.json"

	# Fresh data is valid and round-trips.
	sm.data = SaveManagerScript.default_data()
	sm.data.pearls = 42
	sm.data.catches.append({"fish": "magatum", "pearls": 5, "caught_at": "2026-11-08T12:00:00"})
	var text: String = sm.to_json()
	var other: Node = SaveManagerScript.new()
	var result: Dictionary = other.apply_json(text)
	_check(result.ok, "valid save is accepted")
	_check(int(other.data.pearls) == 42, "pearls survive the round trip")
	_check(other.data.catches.size() == 1, "catches survive the round trip")

	# Local save writes and reads back.
	_check(sm.save_local(), "local save writes")
	var reloaded: Node = SaveManagerScript.new()
	reloaded.save_path = sm.save_path
	reloaded.load_local()
	_check(int(reloaded.data.pearls) == 42, "local save reads back")

	# Bad input is rejected without touching current data.
	other.data.pearls = 7
	_check(not other.apply_json("not json").ok, "non-JSON is rejected")
	_check(not other.apply_json("[1, 2, 3]").ok, "a JSON array is rejected")
	_check(not other.apply_json('{"format": "something-else", "version": 1}').ok, "wrong format is rejected")
	_check(not other.apply_json('{"format": "sinoi-save"}').ok, "missing version is rejected")
	_check(not other.apply_json('{"format": "sinoi-save", "version": 999}').ok, "newer version is rejected")
	_check(int(other.data.pearls) == 7, "rejected imports leave data untouched")

	# Missing keys are filled and wrong types are replaced by defaults.
	var partial: Dictionary = other.apply_json('{"format": "sinoi-save", "version": 1, "pearls": "lots"}')
	_check(partial.ok, "partial save is accepted")
	_check(int(other.data.pearls) == 0, "wrong-typed value falls back to the default")
	_check(other.data.has("settings") and other.data.settings.has("left_handed"), "missing keys are filled")

	# Version 1 saves migrate to version 2 (playtest results added, data kept).
	var v1: Dictionary = other.apply_json('{"format": "sinoi-save", "version": 1, "pearls": 9}')
	_check(v1.ok, "a version 1 save is accepted")
	_check(int(other.data.version) == SaveManagerScript.VERSION, "a version 1 save is upgraded to the current version")
	_check(int(other.data.pearls) == 9, "migration keeps existing data")
	_check(other.data.has("playtest") and other.data.playtest.fight_modes.is_empty(), "migration adds empty fight-box playtest results")

	# Fight-box playtest results survive a round trip.
	sm.data.playtest.fight_modes["hold_hop"] = {"feel": 3, "catches": 2, "escapes": 1, "catch_seconds": 21.5, "good": 8.0, "judged": 10.0}
	var round_trip: Node = SaveManagerScript.new()
	_check(round_trip.apply_json(sm.to_json()).ok, "save with playtest results is accepted")
	_check(int(round_trip.data.playtest.fight_modes.hold_hop.feel) == 3, "playtest ratings survive the round trip")
	var restored := FightSession.from_dict(round_trip.data.playtest.fight_modes.hold_hop)
	_check(restored.catches == 2 and is_equal_approx(restored.average_catch_time(), 10.75), "playtest totals restore into a session")
	round_trip.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.save_path))
	sm.free()
	other.free()
	reloaded.free()

	if _failures == 0:
		print("All SaveManager tests passed.")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)
