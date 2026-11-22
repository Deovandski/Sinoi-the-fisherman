extends FightMode
## Hold Hop: press a small spot as its ring closes, hold inside it until it
## fills, lift on cue, then hop to the next spot (already shown faintly).
## Timing (the press and the lift) is judged harder than aim: landing a
## little off-center only trims the reward, but pressing or lifting at the
## wrong moment costs real meter. Drifting outside the spot for longer than
## `leave_limit` seconds breaks the hold.

enum State { APPROACH, HOLD, GAP }

var spot := Vector2.ZERO
var next_spot := Vector2.ZERO
var state := State.APPROACH
## Pad time when the press should land (the ring meets the spot).
var press_at := 0.0
var hold_for := 1.0
var _hold_start := 0.0
var _finger := -1
var _outside := 0.0
var _gap_until := 0.0


func _start() -> void:
	spot = _random_spot(center())
	next_spot = _random_spot(spot)
	press_at = num("approach", 0.9)
	hold_for = rng.randf_range(num("hold_min", 0.8), num("hold_max", 1.6))


## Fraction of the hold done (1.0 = time to lift).
func hold_progress() -> float:
	return clampf((time - _hold_start) / hold_for, 0.0, 1.0) if state == State.HOLD else 0.0


func _step(delta: float, fingers: Dictionary) -> float:
	var change := 0.0
	match state:
		State.APPROACH:
			cue = "Press when the ring closes"
			if time > press_at + num("ok", 0.25):
				change -= _miss("Missed", spot)
				_next_spot()
		State.HOLD:
			var done_at := _hold_start + hold_for
			cue = "LIFT!" if time >= done_at - num("perfect", 0.12) else "Hold..."
			if not fingers.has(_finger):
				return 0.0
			var inside: bool = fingers[_finger].distance_to(spot) <= num("radius", 7.0) + num("slack", 4.0)
			if inside:
				_outside = 0.0
				if time < done_at:
					change += num("hold_fill", 0.06) * delta
					judge(1.0, delta * 0.5)
			else:
				_outside += delta
				judge(0.0, delta * 0.5)
				cue = "Back in the spot!"
				if _outside > num("leave_limit", 0.3):
					change -= _miss("Slipped", spot, num("slip", 0.12))
					_next_spot()
					return change
			if time > done_at + num("ok", 0.25):
				change -= _miss("Too late", spot, num("timing_miss", 0.12) * 0.8)
				_next_spot()
		State.GAP:
			cue = ""
			if time >= _gap_until:
				state = State.APPROACH
	return change


func touch(index: int, at: Vector2, pressed: bool) -> float:
	var r := num("radius", 7.0)
	var slack := num("slack", 4.0)
	if pressed:
		if state != State.APPROACH or _finger != -1:
			return 0.0
		var dist := at.distance_to(spot)
		if dist > r + slack:
			pop(at, "Off spot", RED)
			judge(0.0, 0.25)
			return -num("stray", 0.02)
		var error := time - press_at
		if error < -num("ok", 0.25):
			var cost := _miss("Too early", spot)
			_next_spot()
			return -cost
		var timing := 1.0 if absf(error) <= num("perfect", 0.12) else 0.5
		var aim := 1.0 if dist <= r * 0.5 else (0.75 if dist <= r else 0.45)
		judge(timing * aim)
		pop(spot, "Perfect" if timing == 1.0 and aim == 1.0 else ("Good" if timing == 1.0 else "OK"), GREEN if timing == 1.0 else GOLD)
		sfx("hit")
		state = State.HOLD
		_finger = index
		_hold_start = time
		_outside = 0.0
		return num("press_gain", 0.07) * timing * aim
	# Lifted.
	if index != _finger:
		return 0.0
	_finger = -1
	if state != State.HOLD:
		return 0.0
	var release_error := time - (_hold_start + hold_for)
	if release_error < -num("perfect", 0.12):
		var cost := _miss("Too soon", spot)
		_next_spot()
		return -cost
	var quality := 1.0 if absf(release_error) <= num("perfect", 0.12) else 0.5
	judge(quality)
	pop(spot, "Clean lift" if quality == 1.0 else "Lift OK", GREEN if quality == 1.0 else GOLD)
	sfx("hit")
	_next_spot()
	return num("release_gain", 0.07) * quality


func _miss(label: String, at: Vector2, cost := -1.0) -> float:
	judge(0.0)
	pop(at, label, RED)
	sfx("miss")
	return num("timing_miss", 0.12) if cost < 0.0 else cost


func _next_spot() -> void:
	spot = next_spot
	next_spot = _random_spot(spot)
	hold_for = rng.randf_range(num("hold_min", 0.8), num("hold_max", 1.6))
	state = State.GAP
	_gap_until = time + 0.15
	press_at = _gap_until + num("approach", 0.9)
	_outside = 0.0
	# A finger still down from the last spot has to lift before the next press.


func _random_spot(from: Vector2) -> Vector2:
	var margin := num("radius", 7.0) + 8.0
	for _i in 12:
		var p := from + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(side * 0.2, side * 0.45)
		if p == clamp_in_pad(p, margin):
			return p
	return clamp_in_pad(from + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * side * 0.3, margin)


func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	var r := num("radius", 7.0)
	if not shadow:
		ring(canvas, spot, r, FAINT)
		return
	# Next spot, faint, so the hop can be planned.
	ring(canvas, next_spot, r, Color(1, 1, 1, 0.18))
	canvas.draw_line(spot, next_spot, Color(1, 1, 1, 0.08), 1.0)
	canvas.draw_circle(spot, r, Color(1, 0.82, 0.4, 0.35))
	ring(canvas, spot, r, GOLD)
	ring(canvas, spot, r + num("slack", 4.0), Color(1, 1, 1, 0.15))
	if state == State.APPROACH:
		var left := maxf(0.0, press_at - time)
		var approach := num("approach", 0.9)
		if left <= approach:
			ring(canvas, spot, r + 22.0 * left / approach, Color(1, 1, 1, 0.8))
	elif state == State.HOLD:
		var done := hold_progress()
		progress_arc(canvas, spot, r + 3.0, done, GREEN if done < 1.0 else WHITE, 2.0)
		if done >= 1.0 and int(time * 10.0) % 2 == 0:
			ring(canvas, spot, r + 6.0, WHITE)
