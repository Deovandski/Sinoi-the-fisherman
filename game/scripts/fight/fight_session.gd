class_name FightSession
extends RefCounted
## The catch meter and the running stats for one mode in the touch test.
## Stats live only for the session (nothing is saved), so testers copy them
## with the "Copy" button.

const START := 0.25

var progress := START
var catches := 0
var escapes := 0
var good := 0.0
var judged := 0.0
## How hard the tester said it felt, 1..5 (0 = not rated yet).
var feel := 0
var catch_times: Array[float] = []
var _since := 0.0


func tick(delta: float) -> void:
	_since += delta


## Applies a meter change. Returns 1 on a catch, -1 when the fish gets away.
func add(change: float) -> int:
	progress += change
	if progress >= 1.0:
		catches += 1
		catch_times.append(_since)
		_restart()
		return 1
	if progress <= 0.0:
		escapes += 1
		_restart()
		return -1
	return 0


func add_judgement(totals: Vector2) -> void:
	good += totals.x
	judged += totals.y


func accuracy() -> float:
	return good / judged if judged > 0.0 else 0.0


func average_catch_time() -> float:
	if catch_times.is_empty():
		return 0.0
	var total := 0.0
	for t in catch_times:
		total += t
	return total / catch_times.size()


func played() -> bool:
	return judged > 0.0 or catches > 0 or escapes > 0 or feel > 0


func _restart() -> void:
	progress = START
	_since = 0.0
