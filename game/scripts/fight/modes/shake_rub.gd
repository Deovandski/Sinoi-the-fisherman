extends FightMode
## Shake: the fish alternates between SHAKE (shake the phone hard enough to
## fill the gauge past the line) and STILL (keep the phone calm while it
## tires; shaking then costs meter). Like WarioWare: Smooth Moves' shakes and
## a "button mashing" catch from fishing games.
##
## Phones without a motion sensor (and desktops) fall back to rubbing: move
## a finger back and forth in the pad, like WarioWare: Touched!'s rub games.
## Only back-and-forth counts, so one long swipe doesn't fill it.

var shaking := true
var level := 0.0         # 0..~2, 1.0 = the SHAKE line
var has_sensor := false
var phase_end := 0.0
var _low_pass := Vector3.ZERO
var _sensor_energy := 0.0
var _rub_energy := 0.0
var _last_finger: Variant = null
var _last_dir := 0.0
var _turns: Array[float] = []


func _start() -> void:
	phase_end = rng.randf_range(num("shake_min", 2.0), num("shake_max", 3.5))


func uses_motion() -> bool:
	return true


func motion(acceleration: Vector3, available: bool) -> void:
	has_sensor = available
	if not available:
		return
	# High-pass: remove gravity and slow tilts, keep the shake.
	if _low_pass == Vector3.ZERO:
		_low_pass = acceleration
	_low_pass = _low_pass.lerp(acceleration, 0.1)
	var shake := (acceleration - _low_pass).length()
	_sensor_energy = lerpf(_sensor_energy, shake, 0.2)


func _step(delta: float, fingers: Dictionary) -> float:
	if time >= phase_end:
		shaking = not shaking
		phase_end = time + (rng.randf_range(num("shake_min", 2.0), num("shake_max", 3.5)) if shaking else rng.randf_range(num("still_min", 1.2), num("still_max", 2.2)))
		sfx("tock")
	_read_rub(delta, fingers)
	level = _sensor_energy / num("shake_threshold", 7.0) if has_sensor else _rub_energy / num("rub_speed", 200.0)
	var word := "SHAKE!" if has_sensor else "RUB!"
	if shaking:
		cue = word
		if level >= 1.0:
			judge(1.0, delta)
			return num("fill", 0.13) * delta
		judge(level, delta)
		return -num("drain", 0.05) * delta
	cue = "STILL..."
	if level >= 1.0:
		judge(0.0, delta)
		cue = "Too much!"
		return -num("too_much", 0.25) * delta
	judge(1.0 if level < 0.4 else 0.5, delta)
	return num("still_fill", 0.05) * delta if level < 0.4 else 0.0


## Rub energy: finger speed, counted only while the finger keeps reversing
## direction (at least two turns in the last second).
func _read_rub(delta: float, fingers: Dictionary) -> void:
	_turns = _turns.filter(func(t): return time - t < 1.0)
	var speed := 0.0
	var finger: Variant = null
	for p in fingers.values():
		finger = p
		break
	if finger != null and _last_finger != null and delta > 0.0:
		var move: Vector2 = finger - _last_finger
		speed = move.length() / delta
		if move.length() > 1.5:
			var dir := move.angle()
			if absf(wrapf(dir - _last_dir, -PI, PI)) > PI * 0.6:
				_turns.append(time)
			_last_dir = dir
	_last_finger = finger
	var target := speed if _turns.size() >= 2 else 0.0
	_rub_energy = lerpf(_rub_energy, target, 1.0 - exp(-5.0 * delta))


func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	var c := center()
	if not shadow:
		if not has_sensor:
			canvas.draw_line(c + Vector2(-side * 0.3, 0), c + Vector2(side * 0.3, 0), FAINT, 1.0)
		return
	# Gauge: a tall bar with the SHAKE line; the fish wobbles with the level.
	var bar := Rect2(side * 0.15, 10, 8, side - 20)
	canvas.draw_rect(bar, Color(1, 1, 1, 0.12))
	var top := 2.0
	var fill := clampf(level / top, 0.0, 1.0)
	var color := GREEN if (shaking and level >= 1.0) or (not shaking and level < 0.4) else (RED if not shaking and level >= 1.0 else GOLD)
	canvas.draw_rect(Rect2(bar.position.x, bar.end.y - bar.size.y * fill, bar.size.x, bar.size.y * fill), color)
	var line_y := bar.end.y - bar.size.y / top
	canvas.draw_line(Vector2(bar.position.x - 3, line_y), Vector2(bar.end.x + 3, line_y), WHITE, 1.0)
	var calm_y := bar.end.y - bar.size.y * 0.4 / top
	canvas.draw_line(Vector2(bar.position.x - 2, calm_y), Vector2(bar.end.x + 2, calm_y), Color(1, 1, 1, 0.4), 1.0)
	var wobble := Vector2(sin(time * 40.0), cos(time * 33.0)) * minf(level, 2.0) * 4.0
	var fish := c + Vector2(side * 0.12, 0) + wobble
	canvas.draw_circle(fish, 10.0, Color(0.94, 0.28, 0.44, 0.7))
	canvas.draw_colored_polygon(PackedVector2Array([fish + Vector2(8, 0), fish + Vector2(18, -7), fish + Vector2(18, 7)]), Color(0.94, 0.28, 0.44, 0.7))
	text(canvas, Vector2(c.x + side * 0.12, side - 12), ("Shake the phone" if has_sensor else "Rub back and forth"), Color(1, 1, 1, 0.7))
