extends FightMode
## Reel Spin: circle one finger clockwise around the reel to wind in line
## (osu!'s spinner, made into a reel). Spin speed has to sit in a band:
## too slow and the fish pulls line back, too fast and tension builds.
## Now and then the fish makes a run: ease off (nearly stop) until it
## tires, or the tension snaps the line and costs a big chunk of meter.

var spin := 0.0          # smoothed turns per second, clockwise positive
var tension := 0.0       # 0..1, snaps at 1
var running := false
var phase_end := 0.0
var angle := -PI / 2.0   # handle angle
var _last_angle := 0.0
var _has_last := false


func _start() -> void:
	phase_end = rng.randf_range(num("reel_min", 3.0), num("reel_max", 5.0))


func _step(delta: float, fingers: Dictionary) -> float:
	if time >= phase_end:
		running = not running
		if running:
			phase_end = time + rng.randf_range(num("run_min", 1.5), num("run_max_time", 2.5))
			pop(center(), "RUN!", RED)
			sfx("tock")
		else:
			phase_end = time + rng.randf_range(num("reel_min", 3.0), num("reel_max", 5.0))
	_read_spin(delta, fingers)
	var change := 0.0
	var low := num("band_low", 0.8)
	var high := num("band_high", 2.2)
	var limit := num("run_max", 0.35) if running else high
	if spin > limit:
		tension += num("tension_up", 1.2) * delta * (2.0 if running else 1.0)
	else:
		tension -= num("tension_down", 0.6) * delta
	tension = clampf(tension, 0.0, 1.0)
	if tension >= 1.0:
		tension = 0.0
		judge(0.0)
		pop(center(), "SNAP!", RED)
		sfx("miss")
		return -num("snap", 0.25)
	if running:
		cue = "Ease off!" if spin > limit else "Let it run..."
		judge(1.0 if spin <= limit else 0.0, delta)
		change += num("drain", 0.04) * 0.25 * delta if spin <= limit else 0.0
	else:
		if spin >= low and spin <= high:
			cue = "Reeling"
			judge(1.0, delta)
			change += num("fill", 0.09) * delta
		elif spin < low:
			cue = "Spin clockwise" if spin >= -0.1 else "Other way!"
			judge(0.0, delta)
			change -= num("drain", 0.04) * delta
		else:
			cue = "Too fast!"
			judge(0.5, delta)
	return change


func _read_spin(delta: float, fingers: Dictionary) -> void:
	var raw := 0.0
	var c := center()
	var reel := side * 0.32
	var finger: Variant = null
	for p in fingers.values():
		finger = p
		break
	if finger != null and finger.distance_to(c) >= reel * 0.35 and finger.distance_to(c) <= reel * 1.7:
		var a: float = (finger - c).angle()
		if _has_last and delta > 0.0:
			raw = wrapf(a - _last_angle, -PI, PI) / TAU / delta
		_last_angle = a
		_has_last = true
		angle = a
	else:
		_has_last = false
	spin = lerpf(spin, raw, 1.0 - exp(-6.0 * delta))


func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	var c := center()
	var reel := side * 0.32
	if not shadow:
		ring(canvas, c, reel, FAINT)
		return
	canvas.draw_circle(c, reel, Color(0.07, 0.54, 0.7, 0.18))
	ring(canvas, c, reel, BLUE, 2.0)
	ring(canvas, c, reel * 0.35, Color(1, 1, 1, 0.15))
	var knob := c + Vector2.from_angle(angle) * reel
	canvas.draw_line(c, knob, Color(1, 1, 1, 0.35), 2.0)
	canvas.draw_circle(knob, 5.0, GOLD)
	# Clockwise arrow on the rim.
	for k in 3:
		var a := -PI / 2.0 + k * TAU / 3.0 + time * 0.5
		var tip := c + Vector2.from_angle(a) * (reel + 6.0)
		var back := c + Vector2.from_angle(a - 0.18) * (reel + 6.0)
		canvas.draw_line(back, tip, Color(1, 1, 1, 0.4), 1.0)
	# Speed meter (left) with the target band, tension meter (right).
	var top := 3.0
	var meter := Rect2(4, 8, 4, side - 16)
	canvas.draw_rect(meter, Color(1, 1, 1, 0.12))
	var low := 0.0 if running else num("band_low", 0.8)
	var high := num("run_max", 0.35) if running else num("band_high", 2.2)
	canvas.draw_rect(Rect2(meter.position.x, meter.end.y - meter.size.y * high / top, meter.size.x, meter.size.y * (high - low) / top), Color(0.02, 0.84, 0.63, 0.5))
	var y := meter.end.y - meter.size.y * clampf(spin / top, 0.0, 1.0)
	canvas.draw_rect(Rect2(meter.position.x - 2, y - 1, meter.size.x + 4, 2), WHITE)
	var t_meter := Rect2(side - 8, 8, 4, side - 16)
	canvas.draw_rect(t_meter, Color(1, 1, 1, 0.12))
	canvas.draw_rect(Rect2(t_meter.position.x, t_meter.end.y - t_meter.size.y * tension, t_meter.size.x, t_meter.size.y * tension), RED.lerp(GOLD, 1.0 - tension))
	text(canvas, Vector2(side - 6, 4), "T", Color(1, 1, 1, 0.6), 6)
