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

	# Version 1 saves migrate to the current version (playtest results added, data kept).
	var v1: Dictionary = other.apply_json('{"format": "sinoi-save", "version": 1, "pearls": 9}')
	_check(v1.ok, "a version 1 save is accepted")
	_check(int(other.data.version) == SaveManagerScript.VERSION, "a version 1 save is upgraded to the current version")
	_check(int(other.data.pearls) == 9, "migration keeps existing data")
	_check(other.data.has("playtest") and other.data.playtest.fight_modes.is_empty(), "migration adds empty fight-box playtest results")

	# Version 2 playtest results move under difficulty level 5.
	var v2: Dictionary = other.apply_json('{"format": "sinoi-save", "version": 2, "playtest": {"fight_modes": {"slide_guide": {"feel": 2, "catches": 4}}}}')
	_check(v2.ok, "a version 2 save is accepted")
	var moved: Dictionary = other.data.playtest.fight_modes.slide_guide
	_check(int(moved.difficulty) == 5 and int(moved.levels["5"].catches) == 4, "version 2 results move to difficulty 5")
	_check(not moved.levels["5"].has("feel"), "old \"How hard?\" ratings are dropped")

	# Version 3 saves lose their ratings and gain fish-test results.
	var v3: Dictionary = other.apply_json('{"format": "sinoi-save", "version": 3, "playtest": {"fight_modes": {"hold_hop": {"difficulty": 7, "levels": {"7": {"feel": 4, "catches": 1}}}}}}')
	_check(v3.ok, "a version 3 save is accepted")
	_check(int(other.data.playtest.fight_modes.hold_hop.levels["7"].catches) == 1 and not other.data.playtest.fight_modes.hold_hop.levels["7"].has("feel"), "version 3 keeps results and drops ratings")
	_check(other.data.playtest.has("fish") and other.data.playtest.fish.is_empty(), "version 3 gains empty fish-test results")

	# Version 4 saves gain an empty streak and keep fish results.
	var v4: Dictionary = other.apply_json('{"format": "sinoi-save", "version": 4, "playtest": {"fight_modes": {}, "fish": {"karkoi": {"catches": 3}}}}')
	_check(v4.ok, "a version 4 save is accepted")
	_check(int(other.data.playtest.fish.karkoi.catches) == 3, "version 4 keeps fish results")
	_check(int(other.data.playtest.streak.current) == 0 and int(other.data.playtest.streak.best) == 0, "version 4 gains an empty streak")

	# Version 5 catches gain quality, size and streak; fish results gain bests.
	var v5: Dictionary = other.apply_json('{"format": "sinoi-save", "version": 5, "catches": [{"fish": "karkoi", "pearls": 3, "caught_at": "2026-11-22T10:00:00"}], "playtest": {"fight_modes": {}, "fish": {"karkoi": {"catches": 1}}, "streak": {"current": 1, "best": 1}}}')
	_check(v5.ok, "a version 5 save is accepted")
	var old_catch: Dictionary = other.data.catches[0]
	_check(int(old_catch.pearls) == 3 and int(old_catch.quality) == 0 and float(old_catch.size_cm) == 0.0 and int(old_catch.streak) == 0, "version 5 catches keep their data and gain quality, size and streak")
	_check(other.data.playtest.fish.karkoi.has("best_size_cm") and other.data.playtest.fish.karkoi.has("best_quality"), "version 5 fish results gain best size and quality")

	# Fight-box playtest results survive a round trip.
	sm.data.playtest.fight_modes["hold_hop"] = {"difficulty": 7, "levels": {"7": {"catches": 2, "escapes": 1, "catch_seconds": 21.5, "good": 8.0, "judged": 10.0}}}
	var round_trip: Node = SaveManagerScript.new()
	_check(round_trip.apply_json(sm.to_json()).ok, "save with playtest results is accepted")
	_check(int(round_trip.data.playtest.fight_modes.hold_hop.difficulty) == 7, "the chosen difficulty survives the round trip")
	sm.data.playtest.fish["sanbi"] = {"catches": 1, "escapes": 2, "catch_seconds": 40.0, "good": 5.0, "judged": 9.0}
	sm.data.playtest.streak = {"current": 2, "best": 6}
	_check(round_trip.apply_json(sm.to_json()).ok and int(round_trip.data.playtest.fish.sanbi.escapes) == 2, "fish-test results survive the round trip")
	_check(int(round_trip.data.playtest.streak.best) == 6, "the streak survives the round trip")
	var restored := FightSession.from_dict(round_trip.data.playtest.fight_modes.hold_hop.levels["7"])
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
