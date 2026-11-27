extends FightMode
## Beat Notes: a rhythm mode in the spirit of osu! and Project Diva (mechanics
## only). Numbered circles appear ahead of time with a ring that closes on
## the beat; tap when it meets the circle. Drag notes are tapped, then held
## while following a ball along a path (osu!'s sliders, Ouendan's phrase
## markers). A metronome ticks the beat. The chart is endless and generated
## a bar at a time, starting sparse and adding drags and half-beats as the
## fight goes on (`ramp_time`).
##
## Timing windows follow osu!'s shape (perfect / good / ok, misses outside),
## sized wider than osu! defaults because phone touch latency varies.

const PATTERNS := {
	"sparse": [[0.0, "tap"], [2.0, "tap"]],
	"quarters": [[0.0, "tap"], [1.0, "tap"], [2.0, "tap"], [3.0, "tap"]],
	"drag": [[0.0, "tap"], [1.0, "tap"], [2.0, "drag", 1.0]],
	"long_drag": [[0.0, "drag", 2.0], [2.5, "tap"], [3.0, "tap"]],
	"eighths": [[0.0, "tap"], [1.0, "tap"], [1.5, "tap"], [2.0, "tap"], [3.0, "tap"]],
}

var notes: Array[Dictionary] = []
var _beat := 0.625
var _origin := 2.0
var _generated_until := 0.0
var _last_pos := Vector2.ZERO
var _last_dir := 0.0
var _last_beat_index := -1000


func _start() -> void:
	_beat = 60.0 / num("bpm", 96.0)
	_origin = num("preempt", 1.2) + 0.8
	_generated_until = _origin
	_last_pos = center()
	_last_dir = rng.randf() * TAU
	_generate()


func max_fingers() -> int:
	return 2


## The next note still waiting to be hit (tests use it).
func next_note() -> Dictionary:
	for n in notes:
		if n.state == "wait":
			return n
	return {}


func _now() -> float:
	return time - num("offset_ms", 0.0) / 1000.0


func _step(delta: float, fingers: Dictionary) -> float:
	_generate()
	var change := 0.0
	var now := _now()
	# Metronome.
	var beat_index := floori((time - _origin) / _beat)
	if beat_index != _last_beat_index:
		_last_beat_index = beat_index
		sfx("tock" if posmod(beat_index, 4) == 0 else "tick")
	for n in notes:
		if n.state == "wait" and now > n.t + num("ok", 0.18):
			n.state = "done"
			change -= _miss(n.pos, tr("Miss"))
		elif n.state == "held":
			change += _follow(n, now, delta, fingers)
	notes = notes.filter(func(n): return not (n.state == "done" and now > n.t + n.dur + 0.4))
	cue = ""
	for n in notes:
		if n.state == "held":
			cue = tr("Follow the ball")
	return change


func _follow(n: Dictionary, now: float, delta: float, fingers: Dictionary) -> float:
	var u: float = (now - n.t) / n.dur
	var change := 0.0
	if not fingers.has(n.finger):
		return 0.0
	var ball := _path(n, minf(u, 1.0))
	if fingers[n.finger].distance_to(ball) > num("follow", 16.0):
		n.off += delta
		if n.off > 0.15:
			n.state = "done"
			return -_miss(ball, tr("Break"), num("break", 0.06))
	else:
		n.off = 0.0
	# Ticks every half beat while following.
	var ticks_due := floori(minf(u, 1.0) * n.dur / (_beat / 2.0))
	while n.ticks < ticks_due:
		n.ticks += 1
		judge(1.0, 0.25)
		change += num("tick", 0.01)
	if u >= 1.0:
		n.state = "done"
		judge(1.0)
		pop(ball, tr("OK"), GREEN)
		sfx("hit")
		change += num("gain", 0.05) * 0.6
	return change


func touch(index: int, at: Vector2, pressed: bool) -> float:
	var now := _now()
	if not pressed:
		for n in notes:
			if n.state == "held" and n.finger == index:
				n.state = "done"
				var u: float = (now - n.t) / n.dur
				if u < 0.85:
					return -_miss(_path(n, clampf(u, 0.0, 1.0)), tr("Break"), num("break", 0.06))
				judge(1.0)
				pop(n.end, tr("OK"), GREEN)
				return num("gain", 0.05) * 0.6
		return 0.0
	var reach := num("radius", 10.0) + 4.0
	for n in notes:
		if n.state != "wait" or absf(now - n.t) > num("early", 0.35):
			continue
		if at.distance_to(n.pos) > reach:
			continue
		var error: float = now - n.t
		if error < -num("ok", 0.18):
			n.state = "done"
			return -_miss(n.pos, tr("Early"))
		var grade := 1.0
		var label := tr("Perfect")
		if absf(error) > num("good", 0.12):
			grade = 0.33
			label = tr("OK")
		elif absf(error) > num("perfect", 0.06):
			grade = 0.66
			label = tr("Good")
		judge(grade)
		pop(n.pos, label, GREEN if grade == 1.0 else GOLD)
		sfx("hit")
		if n.kind == "drag":
			n.state = "held"
			n.finger = index
		else:
			n.state = "done"
		return num("gain", 0.05) * grade
	return 0.0


func _miss(at: Vector2, label: String, cost := -1.0) -> float:
	judge(0.0)
	pop(at, label, RED)
	sfx("miss")
	return num("miss", 0.08) if cost < 0.0 else cost


# --- Chart generation --------------------------------------------------------

func _generate() -> void:
	while _generated_until < time + num("preempt", 1.2) + _beat * 8.0:
		var level := time / num("ramp_time", 20.0)
		var choices := ["sparse", "quarters", "quarters"]
		if level >= 1.0:
			choices += ["drag", "long_drag"]
		if level >= 1.6:
			choices += ["eighths"]
		var pattern: Array = PATTERNS[choices[rng.randi() % choices.size()]]
		var number := 1
		var last_t := _generated_until - _beat
		for item in pattern:
			var t: float = _generated_until + float(item[0]) * _beat
			notes.append(_make_note(t, t - last_t, item, number))
			last_t = t + (float(item[2]) * _beat if item.size() > 2 else 0.0)
			number += 1
		_generated_until += _beat * 4.0


func _make_note(t: float, gap: float, item: Array, number: int) -> Dictionary:
	var margin := num("radius", 10.0) + 4.0
	var distance := clampf(14.0 + 24.0 * gap / _beat, 16.0, 48.0)
	var pos := _last_pos
	for _i in 8:
		_last_dir += rng.randf_range(-1.1, 1.1)
		pos = _last_pos + Vector2.from_angle(_last_dir) * distance
		if pos == clamp_in_pad(pos, margin):
			break
		_last_dir += PI
	pos = clamp_in_pad(pos, margin)
	var note := {"t": t, "kind": item[1], "pos": pos, "end": pos, "ctrl": pos, "dur": 0.0,
		"number": number, "state": "wait", "finger": -1, "ticks": 0, "off": 0.0}
	if item[1] == "drag":
		note.dur = float(item[2]) * _beat
		var length := rng.randf_range(30.0, 50.0) * (1.0 + 0.3 * (float(item[2]) - 1.0))
		var end := pos
		for _i in 8:
			end = pos + Vector2.from_angle(_last_dir + rng.randf_range(-0.8, 0.8)) * length
			if end == clamp_in_pad(end, margin):
				break
			_last_dir += PI / 2.0
		end = clamp_in_pad(end, margin)
		var bend := (end - pos).orthogonal().normalized() * rng.randf_range(-14.0, 14.0)
		note.end = end
		note.ctrl = clamp_in_pad((pos + end) / 2.0 + bend, margin)
		_last_dir = (end - pos).angle()
		pos = end
	_last_pos = pos
	return note


func _path(n: Dictionary, u: float) -> Vector2:
	var a: Vector2 = n.pos.lerp(n.ctrl, u)
	var b: Vector2 = n.ctrl.lerp(n.end, u)
	return a.lerp(b, u)


# --- Drawing -------------------------------------------------------------------

func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	var now := _now()
	var r := num("radius", 10.0)
	var preempt := num("preempt", 1.2)
	for i in range(notes.size() - 1, -1, -1):
		var n: Dictionary = notes[i]
		if n.state == "done" or now < n.t - preempt:
			continue
		var fade := clampf((now - (n.t - preempt)) / (preempt / 3.0), 0.0, 1.0)
		if not shadow:
			if n.t - now < 0.6:
				ring(canvas, n.pos, r, Color(FAINT, FAINT.a * fade))
			continue
		if n.kind == "drag":
			var points := PackedVector2Array()
			for k in 13:
				points.append(_path(n, k / 12.0))
			canvas.draw_polyline(points, Color(0.07, 0.54, 0.7, 0.45 * fade), r * 1.6)
			ring(canvas, n.end, r, Color(1, 1, 1, 0.5 * fade))
		var held: bool = n.state == "held"
		if held:
			var ball := _path(n, clampf((now - n.t) / n.dur, 0.0, 1.0))
			canvas.draw_circle(ball, r * 0.7, GOLD)
			ring(canvas, ball, num("follow", 16.0), Color(1, 1, 1, 0.5))
		else:
			canvas.draw_circle(n.pos, r, Color(0.94, 0.28, 0.44, 0.75 * fade) if n.kind == "tap" else Color(0.07, 0.54, 0.7, 0.85 * fade))
			ring(canvas, n.pos, r, Color(1, 1, 1, fade))
			text(canvas, n.pos, str(n.number), Color(1, 1, 1, fade))
			if now < n.t:
				ring(canvas, n.pos, r * (1.0 + 2.2 * (n.t - now) / preempt), Color(1, 1, 1, 0.8 * fade))
