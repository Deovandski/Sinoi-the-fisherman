class_name FishFight
extends RefCounted
## One fish's fight: a row of sections, each played with one fight-box mode.
##
## Each section has its own meter segment. The first starts at the rules'
## `start` fill; filling a segment moves on to the next section (a new mode);
## filling the last catches the fish. If the current segment empties, the
## fish gets away.
##
## Decided by Deovandski (2026-11-22):
## - Difficulty follows the fish's `curve` as a segment fills: "climb" rises
##   through the section's range (the fish fights harder as it tires);
##   "bell" peaks halfway and eases back.
## - A strong section carries over: the next segment starts with a head
##   start of up to `carry_max`, scaled by the accuracy of the section just
##   finished (above `carry_threshold`). Good play is rewarded right away,
##   and catch streaks are easier to keep while chasing harder fish.

enum Result { NONE, SECTION_DONE, CAUGHT, ESCAPED }

const START := 0.25

var fish: Dictionary
var section := 0
var fills: Array[float] = []
## Head start the current section got from the one before (0 for the first).
var last_carry := 0.0
var start := START
var carry_max := 0.25
var carry_threshold := 0.5
var _side := 120.0
var _overrides := {}
var _good := 0.0
var _judged := 0.0


## `overrides` go to every mode (tests use it to fix the random seed).
func _init(p_fish: Dictionary, side: float, overrides := {}) -> void:
	fish = p_fish
	_side = side
	_overrides = overrides
	var rules := FishCatalog.rules()
	start = float(rules.get("start", START))
	carry_max = float(rules.get("carry_max", 0.25))
	carry_threshold = float(rules.get("carry_threshold", 0.5))
	restart()


func restart() -> void:
	section = 0
	last_carry = 0.0
	fills.clear()
	for i in section_count():
		fills.append(start if i == 0 else 0.0)
	_begin_section()


func section_count() -> int:
	return maxi(fish.get("sections", []).size(), 1)


func section_mode_id() -> String:
	return str(fish.sections[section].mode)


func curve() -> String:
	return str(fish.get("curve", "climb"))


## The current section's difficulty range, as [from, to] on the 0..1 scale.
func section_range() -> Vector2:
	var r: Array = fish.sections[section].get("difficulty", [0.5, 0.5])
	return Vector2(float(r[0]), float(r[1]))


## How far through the current section the player is, 0..1.
func section_progress() -> float:
	return clampf((fills[section] - start) / (1.0 - start), 0.0, 1.0)


## Difficulty right now, from the section's range and the fish's curve.
func difficulty() -> float:
	var r := section_range()
	var u := section_progress()
	var weight := sin(PI * u) if curve() == "bell" else u
	return lerpf(r.x, r.y, weight)


## Builds the mode for the current section at its current difficulty.
func make_mode(side := -1.0) -> FightMode:
	if side > 0.0:
		_side = side
	return FightCatalog.create(section_mode_id(), _side, _overrides, difficulty())


## Judgement totals from the mode, for the carry-over.
func add_judgement(totals: Vector2) -> void:
	_good += totals.x
	_judged += totals.y


## Accuracy of the current section so far, 0..1.
func section_accuracy() -> float:
	return _good / _judged if _judged > 0.0 else 0.0


## Head start a section played at `accuracy` earns for the next one.
func carry_for(accuracy: float) -> float:
	if carry_threshold >= 1.0:
		return 0.0
	return carry_max * clampf((accuracy - carry_threshold) / (1.0 - carry_threshold), 0.0, 1.0)


## Applies a meter change to the current section.
func add(amount: float) -> Result:
	fills[section] += amount
	if fills[section] >= 1.0:
		fills[section] = 1.0
		if section >= section_count() - 1:
			return Result.CAUGHT
		last_carry = carry_for(section_accuracy())
		section += 1
		fills[section] = minf(start + last_carry, 0.95)
		_begin_section()
		return Result.SECTION_DONE
	if fills[section] <= 0.0:
		fills[section] = 0.0
		return Result.ESCAPED
	return Result.NONE


func _begin_section() -> void:
	_good = 0.0
	_judged = 0.0


## "Slide Guide 1-3, Reel Spin 2-4" (levels on the 0..10 scale).
func sections_summary() -> String:
	var parts: Array[String] = []
	for s in fish.get("sections", []):
		var mode := FightCatalog.entry(str(s.mode))
		var r: Array = s.get("difficulty", [0.5, 0.5])
		parts.append("%s %d-%d" % [mode.get("name", s.mode), roundi(float(r[0]) * 10.0), roundi(float(r[1]) * 10.0)])
	return ", ".join(parts)
