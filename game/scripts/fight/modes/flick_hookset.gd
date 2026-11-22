extends FightMode
## Hookset: an arrow appears with a ring closing on it; when the ring meets
## the arrow, flick that way (Rhythm Heaven's flick, used to set the hook).
## Sometimes an X appears instead: a decoy, like the Sanbi's fake lures; any
## flick on an X costs meter, waiting it out earns a little. Cues start with
## four directions and slow rings, then add diagonals and speed up.

var cue_dir := Vector2.UP
var decoy := false
## Pad time when the ring closes (the moment to flick).
var go_at := 0.0
var _shown_at := 0.0
var _done := false
var _down := {}  # finger index -> [start position, start time]


func _start() -> void:
	_new_cue(0.6)


func _step(_delta: float, _fingers: Dictionary) -> float:
	var change := 0.0
	if not _done and time > go_at + num("late", 0.38):
		_done = true
		if decoy:
			judge(1.0)
			pop(center(), "Good wait", GREEN)
			change += num("gain", 0.1) * 0.5
		else:
			change -= _miss("Too slow")
	if _done and time > go_at + num("late", 0.38) + 0.35:
		_new_cue(rng.randf_range(0.2, 0.5))
	if decoy:
		cue = "X: don't flick!"
	elif time < _shown_at:
		cue = ""
	else:
		cue = "Flick on the ring"
	return change


func touch(index: int, at: Vector2, pressed: bool) -> float:
	if pressed:
		_down[index] = [at, time]
		return 0.0
	if not _down.has(index):
		return 0.0
	var start: Array = _down[index]
	_down.erase(index)
	var move: Vector2 = at - start[0]
	var duration: float = maxf(time - start[1], 0.001)
	if move.length() < num("min_dist", 16.0) or move.length() / duration < num("min_speed", 160.0):
		return 0.0  # a tap or a slow drag, not a flick
	return _flick(move)


func _flick(move: Vector2) -> float:
	if _done or time < _shown_at:
		return 0.0
	_done = true
	if decoy:
		return -_miss("It was an X!")
	var error := time - go_at
	if error < -num("late", 0.38):
		return -_miss("Too early")
	var allowed := deg_to_rad(30.0) if _cardinal(cue_dir) else deg_to_rad(22.0)
	if absf(move.angle_to(cue_dir)) > allowed:
		return -_miss("Wrong way")
	var grade := 1.0 if absf(error) <= num("perfect", 0.1) else (0.6 if absf(error) <= num("good", 0.22) else 0.3)
	judge(grade)
	pop(center(), ["Hooked!", "Good", "Late" if error > 0.0 else "Early"][0 if grade == 1.0 else (1 if grade == 0.6 else 2)], GREEN if grade == 1.0 else GOLD)
	sfx("hit")
	return num("gain", 0.1) * grade


func _miss(label: String) -> float:
	judge(0.0)
	pop(center(), label, RED)
	sfx("miss")
	return num("miss", 0.1)


func _new_cue(gap: float) -> void:
	var ramp := clampf(time / num("ramp_time", 40.0), 0.0, 1.0)
	var lead := lerpf(num("lead_start", 1.0), num("lead_end", 0.6), ramp)
	var directions := 8 if ramp > 0.4 else 4
	cue_dir = Vector2.UP.rotated(TAU * float(rng.randi() % directions) / directions)
	decoy = time > num("decoy_after", 12.0) and rng.randf() < num("decoy_chance", 0.2)
	_shown_at = time + gap
	go_at = _shown_at + lead
	_done = false


func _cardinal(v: Vector2) -> bool:
	return absf(v.x) < 0.01 or absf(v.y) < 0.01


func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	if time < _shown_at or _done:
		return
	var c := center()
	var size := side * 0.18
	var lead := go_at - _shown_at
	var left := maxf(go_at - time, 0.0)
	if not shadow:
		ring(canvas, c, size, FAINT)
		return
	ring(canvas, c, size, Color(1, 1, 1, 0.4))
	ring(canvas, c, size + 30.0 * left / lead, WHITE)
	if decoy:
		var d := size * 0.55
		canvas.draw_line(c + Vector2(-d, -d), c + Vector2(d, d), RED, 3.0)
		canvas.draw_line(c + Vector2(-d, d), c + Vector2(d, -d), RED, 3.0)
		return
	var tip := c + cue_dir * size * 0.8
	var tail := c - cue_dir * size * 0.8
	canvas.draw_line(tail, tip, GOLD, 3.0)
	var side_dir := cue_dir.orthogonal() * size * 0.4
	canvas.draw_colored_polygon(PackedVector2Array([tip + cue_dir * 3.0, tip - cue_dir * size * 0.45 + side_dir, tip - cue_dir * size * 0.45 - side_dir]), GOLD)
