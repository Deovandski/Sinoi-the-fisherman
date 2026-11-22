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
	_test_bell_curve()
	_test_carry_over()
	_test_rewards()
	_test_journal()
	_test_balls()
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
		_check(str(f.get("curve", "climb")) in ["climb", "bell"], "%s curve is climb or bell" % f.id)
		_check(f.has("size_cm") and f.size_cm.size() == 2 and float(f.size_cm[0]) > 0.0 and float(f.size_cm[0]) < float(f.size_cm[1]), "%s has a size range in cm" % f.id)
		_check(str(f.get("region", "")) != "", "%s has a region" % f.id)
		var lore := str(f.get("lore", ""))
		_check(lore != "" and lore.length() <= 160, "%s has a short lore teaser (a nudge, not a dump)" % f.id)
		one_section = one_section or f.sections.size() == 1
		many_sections = many_sections or f.sections.size() > 1
		for s in f.sections:
			_check(not FightCatalog.entry(str(s.mode)).is_empty(), "%s section mode '%s' exists" % [f.id, s.mode])
			var r: Array = s.difficulty
			_check(r.size() == 2 and float(r[0]) >= 0.0 and float(r[1]) <= 1.0 and float(r[0]) <= float(r[1]), "%s %s difficulty is a range inside 0..1" % [f.id, s.mode])
	_check(one_section and many_sections, "some fish have one section, others several")
	var rules := FishCatalog.rules()
	_check(rules.has("start") and rules.has("carry_max") and rules.has("carry_threshold"), "fish data has the shared rules")
	_check(FishCatalog.lore_link().begins_with("https://"), "fish data links the lore website")
	var rewards := FishCatalog.rewards()
	_check(rewards.get("quality_names", []).size() >= 2 and rewards.quality_names.size() == rewards.get("quality_pearls", []).size(), "rewards name every quality tier and give each a pearl multiplier")
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


func _test_bell_curve() -> void:
	var fish := FishCatalog.entry("karkoi").duplicate(true)
	fish.curve = "bell"
	var fight := FishFight.new(fish, SIDE)
	var r := fight.section_range()
	_check(is_equal_approx(fight.difficulty(), r.x), "bell: starts at the low end")
	fight.add(0.375)
	_check(is_equal_approx(fight.difficulty(), r.y), "bell: peaks halfway")
	fight.add(0.37)
	_check(absf(fight.difficulty() - r.x) < 0.02, "bell: eases back near the end")
	var climb := FishFight.new(FishCatalog.entry("karkoi"), SIDE)
	climb.add(0.74)
	_check(climb.difficulty() > r.y - 0.02, "climb: highest near the end")


func _test_carry_over() -> void:
	var strong := FishFight.new(FishCatalog.entry("bagnazu"), SIDE)
	strong.add_judgement(Vector2(10, 10))  # perfect section
	strong.add(0.8)
	_check(is_equal_approx(strong.last_carry, strong.carry_max), "carry: a perfect section earns the full head start")
	_check(is_equal_approx(strong.fills[1], strong.start + strong.carry_max), "carry: the next section starts higher")
	var weak := FishFight.new(FishCatalog.entry("bagnazu"), SIDE)
	weak.add_judgement(Vector2(4, 10))  # 40% accuracy, below the threshold
	weak.add(0.8)
	_check(weak.last_carry == 0.0 and is_equal_approx(weak.fills[1], weak.start), "carry: a weak section earns nothing")
	var middling := FishFight.new(FishCatalog.entry("bagnazu"), SIDE)
	middling.add_judgement(Vector2(75, 100))  # halfway between threshold and perfect
	middling.add(0.8)
	_check(is_equal_approx(middling.last_carry, middling.carry_max / 2.0), "carry: scales with accuracy above the threshold")
	_check(middling.section_accuracy() == 0.0, "carry: accuracy resets for the new section")


## Averages over many rolls: a long streak beats no streak on quality, size
## and pearls, and every roll stays inside its limits.
func _test_rewards() -> void:
	var fish := FishCatalog.entry("magatum")
	var rewards := FishCatalog.rewards()
	var top: int = rewards.quality_names.size() - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var totals := {}
	var in_limits := true
	for streak in [0, 8]:
		var q := 0.0
		var size := 0.0
		var pearls := 0.0
		for i in 400:
			var r := CatchReward.roll(fish, streak, 0.6, rng)
			q += r.quality
			size += r.size_cm
			pearls += r.pearls
			if r.quality < 0 or r.quality > top or r.size_cm < float(fish.size_cm[0]) or r.size_cm > float(fish.size_cm[1]) or r.bonus > float(rewards.pearls_streak_cap):
				in_limits = false
		totals[streak] = Vector3(q, size, pearls) / 400.0
	_check(in_limits, "rewards: quality, size and bonus stay inside their limits")
	_check(totals[8].x > totals[0].x + 0.5, "rewards: a streak raises quality")
	_check(totals[8].y > totals[0].y + 10.0, "rewards: a streak raises size")
	_check(totals[8].z > totals[0].z * 1.5, "rewards: a streak earns bonus pearls")
	var no_streak := CatchReward.roll(fish, 0, 0.0, rng)
	_check(no_streak.bonus == 0.0 and no_streak.pearls >= int(fish.pearls[0]), "rewards: no streak, no bonus")
	var capped := CatchReward.roll(fish, 50, 1.0, rng)
	_check(capped.quality == top and is_equal_approx(capped.bonus, float(rewards.pearls_streak_cap)), "rewards: very long streaks hit the top tier and the bonus cap")
	var fight := FishFight.new(fish, SIDE)
	fight.add_judgement(Vector2(3, 4))
	fight.add(0.8)
	fight.add_judgement(Vector2(1, 4))
	_check(is_equal_approx(fight.fight_accuracy(), 0.5), "rewards: fight accuracy spans every section")


func _test_journal() -> void:
	var journal := {}
	Journal.record(journal, {"fish": "magatum", "pearls": 6, "quality": 0, "size_cm": 90.0, "caught_at": "2026-11-22T10:00:00"})
	Journal.record(journal, {"fish": "magatum", "pearls": 14, "quality": 2, "size_cm": 142.5, "caught_at": "2026-11-22T10:05:00"})
	Journal.record(journal, {"fish": "magatum", "pearls": 10, "quality": 3, "size_cm": 120.0, "caught_at": "2026-11-22T10:09:00"})
	Journal.record(journal, {"fish": "karkoi", "pearls": 3, "quality": 0, "size_cm": 40.0, "caught_at": "2026-11-22T10:10:00"})
	var m: Dictionary = journal.magatum
	_check(int(m.caught) == 3 and journal.size() == 2, "journal: one entry per fish, counting catches")
	_check(is_equal_approx(float(m.biggest_cm), 142.5) and int(m.biggest_quality) == 2, "journal: keeps the biggest catch and its quality")
	_check(int(m.best_quality) == 3, "journal: keeps the best quality separately")
	_check(is_equal_approx(Journal.average_pearls(m), 10.0), "journal: average payoff in pearls")
	_check(m.first_caught_at == "2026-11-22T10:00:00" and m.last_caught_at == "2026-11-22T10:09:00", "journal: first and last catch times")
	var rebuilt := Journal.rebuild([{"fish": "magatum", "pearls": 6, "size_cm": 90.0}, {"fish": "magatum", "pearls": 14, "size_cm": 142.5}, "junk"])
	_check(int(rebuilt.magatum.caught) == 2 and is_equal_approx(Journal.average_pearls(rebuilt.magatum), 10.0), "journal: rebuilds from a catch log, skipping bad entries")
	_check(Journal.average_pearls({}) == 0.0, "journal: an empty entry averages 0")


func _test_balls() -> void:
	_check(Balls.format(17.0) == "17 pearls", "balls: small amounts stay in pearls")
	_check(Balls.format(1.0) == "1 pearl", "balls: one pearl")
	_check(Balls.format(17.5) == "17.5 pearls", "balls: averages keep a decimal")
	_check(Balls.format(50.0) == "1 amethyst", "balls: 50 pearls is an amethyst")
	_check(Balls.format(103.4) == "2 amethysts, 3.4 pearls", "balls: bigger amounts use bigger balls")
	_check(Balls.format(5051.0) == "1 sapphire, 1 amethyst, 1 pearl", "balls: sapphires, skipping empty balls")
	_check(Balls.format(0.0) == "0 pearls", "balls: nothing is 0 pearls")


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
