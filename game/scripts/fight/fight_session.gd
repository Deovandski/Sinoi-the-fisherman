class_name FightSession
extends RefCounted
## A catch meter plus running stats: one per mode and difficulty level in the
## fight-box test, one per fish in the fish test (which keeps its own section
## meters and only records catches here). Totals are kept in the save file
## (playtest section) so they add up over several sessions.

const START := 0.25

var progress := START
var catches := 0
var escapes := 0
var good := 0.0
var judged := 0.0
## Total seconds spent on caught fish, and the last catch's time.
var catch_seconds := 0.0
var last_catch_time := 0.0
var _since := 0.0


static func from_dict(d: Dictionary) -> FightSession:
	var s := FightSession.new()
	s.catches = maxi(int(d.get("catches", 0)), 0)
	s.escapes = maxi(int(d.get("escapes", 0)), 0)
	s.catch_seconds = maxf(float(d.get("catch_seconds", 0.0)), 0.0)
	s.good = maxf(float(d.get("good", 0.0)), 0.0)
	s.judged = maxf(float(d.get("judged", 0.0)), 0.0)
	return s


## What goes into the save (see docs/SAVE_FORMAT.md, playtest.fight_modes).
func to_dict() -> Dictionary:
	return {"catches": catches, "escapes": escapes,
		"catch_seconds": snappedf(catch_seconds, 0.01), "good": snappedf(good, 0.001), "judged": snappedf(judged, 0.001)}


func tick(delta: float) -> void:
	_since += delta


## Applies a meter change. Returns 1 on a catch, -1 when the fish gets away.
func add(change: float) -> int:
	progress += change
	if progress >= 1.0:
		record_catch()
		return 1
	if progress <= 0.0:
		record_escape()
		return -1
	return 0


func record_catch() -> void:
	catches += 1
	last_catch_time = _since
	catch_seconds += _since
	_restart()


func record_escape() -> void:
	escapes += 1
	_restart()


func add_judgement(totals: Vector2) -> void:
	good += totals.x
	judged += totals.y


func accuracy() -> float:
	return good / judged if judged > 0.0 else 0.0


func average_catch_time() -> float:
	return catch_seconds / catches if catches > 0 else 0.0


func played() -> bool:
	return judged > 0.0 or catches > 0 or escapes > 0


func _restart() -> void:
	progress = START
	_since = 0.0
