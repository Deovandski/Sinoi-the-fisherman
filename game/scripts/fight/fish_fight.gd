class_name FishFight
extends RefCounted
## One fish's fight: a row of sections, each played with one fight-box mode.
##
## Each section has its own meter segment. The first starts a quarter full;
## filling a segment moves on to the next section (a new mode); filling the
## last catches the fish. If the current segment empties, the fish gets
## away. A section's difficulty climbs from the low end of its range to the
## high end as its segment fills, so a fish fights harder as it tires.

enum Result { NONE, SECTION_DONE, CAUGHT, ESCAPED }

const START := 0.25

var fish: Dictionary
var section := 0
var fills: Array[float] = []
var _side := 120.0
var _overrides := {}


## `overrides` go to every mode (tests use it to fix the random seed).
func _init(p_fish: Dictionary, side: float, overrides := {}) -> void:
	fish = p_fish
	_side = side
	_overrides = overrides
	restart()


func restart() -> void:
	section = 0
	fills.clear()
	for i in section_count():
		fills.append(START if i == 0 else 0.0)


func section_count() -> int:
	return maxi(fish.get("sections", []).size(), 1)


func section_mode_id() -> String:
	return str(fish.sections[section].mode)


## The current section's difficulty range, as [from, to] on the 0..1 scale.
func section_range() -> Vector2:
	var r: Array = fish.sections[section].get("difficulty", [0.5, 0.5])
	return Vector2(float(r[0]), float(r[1]))


## Difficulty right now: the section's range, climbing as its meter fills.
func difficulty() -> float:
	var r := section_range()
	return lerpf(r.x, r.y, clampf((fills[section] - START) / (1.0 - START), 0.0, 1.0))


## Builds the mode for the current section at its current difficulty.
func make_mode(side := -1.0) -> FightMode:
	if side > 0.0:
		_side = side
	return FightCatalog.create(section_mode_id(), _side, _overrides, difficulty())


## Applies a meter change to the current section.
func add(amount: float) -> Result:
	fills[section] += amount
	if fills[section] >= 1.0:
		fills[section] = 1.0
		if section >= section_count() - 1:
			return Result.CAUGHT
		section += 1
		fills[section] = START
		return Result.SECTION_DONE
	if fills[section] <= 0.0:
		fills[section] = 0.0
		return Result.ESCAPED
	return Result.NONE


## "Slide Guide 1-3, Reel Spin 2-4" (levels on the 0..10 scale).
func sections_summary() -> String:
	var parts: Array[String] = []
	for s in fish.get("sections", []):
		var mode := FightCatalog.entry(str(s.mode))
		var r: Array = s.get("difficulty", [0.5, 0.5])
		parts.append("%s %d-%d" % [mode.get("name", s.mode), roundi(float(r[0]) * 10.0), roundi(float(r[1]) * 10.0)])
	return ", ".join(parts)
