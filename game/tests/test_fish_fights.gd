extends SceneTree
## Headless tests for the fish data and fish fights (sections). Run:
##   godot --headless --path game -s res://tests/test_fish_fights.gd
## Exits with code 1 on failure.

const SIDE := 120.0
const DT := 1.0 / 60.0

var _failures := 0


func _init() -> void:
	_test_data()
	_test_sections()
	_test_difficulty_climbs()
	_test_escape()
	_test_every_fish_plays()
	if _failures == 0:
		print("All fish fight tests passed.")
	quit(1 if _failures > 0 else 0)


func _test_data() -> void:
	var fish := FishCatalog.entries()
	_check(fish.size() >= 4, "fish data lists the current fish")
	var ids := {}
	var one_section := false
	var many_sections := false
	for f in fish:
		for key in ["id", "name", "pearls", "description", "sections"]:
			_check(f.has(key), "%s has '%s'" % [f.get("id", "?"), key])
		_check(not ids.has(f.id), "%s id is unique" % f.id)
		ids[f.id] = true
		_check(f.pearls.size() == 2 and int(f.pearls[0]) <= int(f.pearls[1]), "%s pearls are a [min, max] range" % f.id)
		_check(f.sections.size() >= 1, "%s has at least one section" % f.id)
		one_section = one_section or f.sections.size() == 1
		many_sections = many_sections or f.sections.size() > 1
		for s in f.sections:
			_check(not FightCatalog.entry(str(s.mode)).is_empty(), "%s section mode '%s' exists" % [f.id, s.mode])
			var r: Array = s.difficulty
			_check(r.size() == 2 and float(r[0]) >= 0.0 and float(r[1]) <= 1.0 and float(r[0]) <= float(r[1]), "%s %s difficulty is a range inside 0..1" % [f.id, s.mode])
	_check(one_section and many_sections, "some fish have one section, others several")
	for canon in ["sanbi"]:
		_check(ids.has(canon), "canon fish %s is in the data" % canon)


func _test_sections() -> void:
	var fight := FishFight.new(FishCatalog.entry("magatum"), SIDE, {"seed": 1})
	_check(fight.section_count() == 3, "magatum has three sections")
	_check(fight.fills == [0.25, 0.0, 0.0], "the first section starts a quarter full, the rest empty")
	_check(fight.section_mode_id() == "flick_hookset", "the first section uses its own mode")
	_check(fight.add(0.8) == FishFight.Result.SECTION_DONE, "filling a section moves to the next")
	_check(fight.section == 1 and fight.fills[0] == 1.0 and is_equal_approx(fight.fills[1], 0.25), "the next section starts a quarter full")
	_check(fight.section_mode_id() == "reel_spin", "the next section switches mode")
	fight.add(0.8)
	_check(fight.add(0.8) == FishFight.Result.CAUGHT, "filling the last section catches the fish")
	fight.restart()
	_check(fight.section == 0 and fight.fills == [0.25, 0.0, 0.0], "restart goes back to the first section")


func _test_difficulty_climbs() -> void:
	var fight := FishFight.new(FishCatalog.entry("karkoi"), SIDE)
	var r := fight.section_range()
	_check(is_equal_approx(fight.difficulty(), r.x), "a section starts at the low end of its range")
	fight.add(0.375)
	_check(is_equal_approx(fight.difficulty(), (r.x + r.y) / 2.0), "difficulty is halfway when the segment is halfway")
	var mode := fight.make_mode()
	_check(is_equal_approx(mode.difficulty, fight.difficulty()), "a new mode starts at the current difficulty")
	var lost := FishFight.new(FishCatalog.entry("sanbi"), SIDE)
	lost.add(0.8)
	lost.add(0.8)
	var lost_ref := lost.make_mode()
	lost_ref.difficulty = 0.77
	_check(is_equal_approx(lost_ref.inner.difficulty, 0.77), "Lost Ref passes live difficulty changes to its inner mode")


func _test_escape() -> void:
	var fight := FishFight.new(FishCatalog.entry("bagnazu"), SIDE)
	fight.add(0.8)
	_check(fight.section == 1, "second section reached")
	_check(fight.add(-0.3) == FishFight.Result.ESCAPED, "emptying any section lets the fish get away")


## Each fish's modes run through a few seconds of scripted pokes at the
## section's difficulty, with the difficulty updated live.
func _test_every_fish_plays() -> void:
	for f in FishCatalog.entries():
		var fight := FishFight.new(f, SIDE, {"seed": 5})
		var sections_seen := 0
		for i in fight.section_count():
			var mode := fight.make_mode()
			var total := 0.0
			for frame in 300:
				mode.difficulty = fight.difficulty()
				total += mode.step(DT, {0: Vector2(60, 60)} if frame % 30 < 15 else {})
			_check(is_finite(total), "%s section %d (%s) runs" % [f.id, i + 1, fight.section_mode_id()])
			sections_seen += 1
			if i < fight.section_count() - 1:
				fight.add(1.0)
		_check(sections_seen == f.sections.size(), "%s plays every section" % f.id)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)
