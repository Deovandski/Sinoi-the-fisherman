extends FightMode
## Tap Tempo: tap anywhere in the pad; only the timing and speed matter.
## The fish changes what it wants every few seconds:
## - Steady: one tap per metronome beat.
## - Faster: keep the tap rate above a target (a Taiko drumroll / a mash).
## - Slower: keep the rate inside a slow band; rushing costs meter.
## - Rhythm: the fish taps a one-bar pattern first ("listen"), then the
##   player repeats it, rests included (call and response, like Rhythm Heaven).
## Two fingers may alternate: index + middle tap faster than one finger.

const RHYTHMS := [
	[0.0, 1.0, 2.0, 2.5, 3.0],
	[0.0, 1.5, 2.0, 3.0],
	[0.0, 0.5, 1.0, 2.0],
	[0.0, 2.0, 2.5, 3.0, 3.5],
]
const GRACE := 0.8

var phase := "steady"
var phase_start := 0.0
var fast_rate := 6.0
var rhythm: Array = RHYTHMS[0]
var _beat := 0.5
var _taps: Array[float] = []
var _ripples: Array = []  # [position, time]
var _hit_slots := {}      # expected-hit key -> true once tapped
var _checked_until := 0.0
var _last_sound_slot := -1


func _start() -> void:
	_beat = 60.0 / num("bpm", 116.0)
	fast_rate = num("fast_rate", 6.0) - 1.0
	_begin("steady")


func max_fingers() -> int:
	return 2


## Start of the judged beat grid for this phase.
func origin() -> float:
	return phase_start + GRACE


## Expected tap times near `t` for the current phase (beats or the pattern).
func expected_near(t: float) -> Array[float]:
	var out: Array[float] = []
	if phase == "steady":
		var k := roundi((t - origin()) / _beat)
		for i in [k - 1, k, k + 1]:
			if i >= 0:
				out.append(origin() + i * _beat)
	elif phase == "rhythm":
		var bar := floori((t - origin()) / (_beat * 4.0))
		for b in [bar - 1, bar, bar + 1]:
			if b < 1:  # bar 0 is the fish's turn ("listen")
				continue
			for p in rhythm:
				out.append(origin() + (b * 4.0 + float(p)) * _beat)
	return out


func rate(window: float) -> float:
	var count := 0
	for t in _taps:
		if t > time - window:
			count += 1
	return count / window


func _step(delta: float, _fingers: Dictionary) -> float:
	_ripples = _ripples.filter(func(r): return time - r[1] < 0.4)
	_taps = _taps.filter(func(t): return time - t < 2.5)
	if time - phase_start >= num("phase_time", 6.0):
		_next_phase()
	var change := 0.0
	var since := time - origin()
	match phase:
		"steady", "rhythm":
			change += _beat_sounds_and_misses(since)
			if phase == "steady":
				cue = tr("Tap on the beat")
			else:
				cue = tr("Listen...") if since < _beat * 4.0 else tr("Your turn: repeat it")
		"faster":
			var r := rate(1.0)
			cue = tr("Faster! %d/s") % int(fast_rate)
			if since > 0.0:
				if r >= fast_rate:
					judge(1.0, delta)
					change += num("rate_fill", 0.1) * delta
				else:
					judge(r / fast_rate, delta)
					change -= num("rate_drain", 0.06) * delta * (1.0 - r / fast_rate)
		"slower":
			var r := rate(2.0)
			var low := num("slow_low", 1.4)
			var high := num("slow_high", 2.6)
			cue = tr("Slow and steady")
			if since > 0.0:
				if r > high:
					cue = tr("Slower!")
					judge(0.0, delta)
					change -= num("rate_drain", 0.06) * delta * 1.5
				elif r < low:
					judge(0.5, delta)
					change -= num("rate_drain", 0.06) * delta * 0.5
				else:
					judge(1.0, delta)
					change += num("rate_fill", 0.1) * delta
	return change


func _beat_sounds_and_misses(since: float) -> float:
	var change := 0.0
	# Metronome tick on each beat (and the fish's pattern in its listen bar).
	if since >= 0.0:
		var slot := floori(since / (_beat / 2.0))
		if slot != _last_sound_slot:
			_last_sound_slot = slot
			var half_beats := float(slot) / 2.0
			if phase == "rhythm" and since < _beat * 4.0:
				if rhythm.has(half_beats):
					sfx("tock")
			elif slot % 2 == 0:
				sfx("tick")
	# Expected taps that passed without a tap are misses.
	var good := num("good", 0.14)
	for t in expected_near(time - good - 0.01):
		if t > _checked_until and t < time - good:
			_checked_until = t
			if not _hit_slots.has(_key(t)):
				change -= _miss(center(), "Missed beat" if phase == "steady" else "Missed")
	return change


func touch(_index: int, at: Vector2, pressed: bool) -> float:
	if not pressed:
		return 0.0
	_taps.append(time)
	_ripples.append([at, time])
	if time < origin() or phase == "faster" or phase == "slower":
		return 0.0
	if phase == "rhythm" and time < origin() + _beat * 4.0 - num("good", 0.14):
		return -_miss(at, tr("Wait, listen"))
	var best := INF
	var best_t := 0.0
	for t in expected_near(time):
		if absf(time - t) < absf(best):
			best = time - t
			best_t = t
	if absf(best) > num("good", 0.14) or _hit_slots.has(_key(best_t)):
		return -_miss(at, "Rest!" if phase == "rhythm" else "Off beat")
	_hit_slots[_key(best_t)] = true
	var grade := 1.0 if absf(best) <= num("perfect", 0.07) else 0.6
	judge(grade)
	pop(at, tr("Perfect") if grade == 1.0 else tr("Good"), GREEN if grade == 1.0 else GOLD)
	sfx("hit")
	return num("hit", 0.035) * grade


func _key(t: float) -> int:
	return roundi(t * 1000.0)


func _miss(at: Vector2, label: String) -> float:
	judge(0.0)
	pop(at, label, RED)
	sfx("miss")
	return num("miss", 0.03)


func _next_phase() -> void:
	var options := ["steady", "faster", "slower", "rhythm"]
	options.erase(phase)
	_begin(options[rng.randi() % options.size()])


func _begin(next: String) -> void:
	phase = next
	phase_start = time
	_hit_slots.clear()
	_checked_until = origin() - 0.001
	_last_sound_slot = -1
	if phase == "faster":
		fast_rate = minf(fast_rate + 1.0, num("fast_rate", 6.0) + 2.0)
	if phase == "rhythm":
		rhythm = RHYTHMS[rng.randi() % RHYTHMS.size()]


func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	var c := center()
	var radius := side * 0.28
	var pulse := 0.0
	var since := time - origin()
	if since >= 0.0 and (phase == "steady" or phase == "rhythm"):
		pulse = 1.0 - fmod(since, _beat) / _beat
	elif phase == "faster":
		pulse = 1.0 - fmod(time * fast_rate, 1.0)
	elif phase == "slower":
		pulse = 1.0 - fmod(time * 2.0, 1.0)
	if not shadow:
		ring(canvas, c, radius, FAINT)
		return
	canvas.draw_circle(c, radius + pulse * 3.0, Color(0.07, 0.54, 0.7, 0.25 + 0.2 * pulse))
	ring(canvas, c, radius + pulse * 3.0, BLUE)
	for r in _ripples:
		var age: float = time - r[1]
		ring(canvas, r[0], 4.0 + age * 40.0, Color(1, 1, 1, 0.8 - age * 2.0))
	if phase == "faster" or phase == "slower":
		_draw_rate_gauge(canvas)
	elif phase == "rhythm":
		_draw_rhythm(canvas)


func _draw_rate_gauge(canvas: CanvasItem) -> void:
	var bar := Rect2(10, side - 12, side - 20, 5)
	var top := 10.0
	canvas.draw_rect(bar, Color(1, 1, 1, 0.12))
	var low := fast_rate if phase == "faster" else num("slow_low", 1.4)
	var high := top if phase == "faster" else num("slow_high", 2.6)
	canvas.draw_rect(Rect2(bar.position.x + bar.size.x * low / top, bar.position.y, bar.size.x * (high - low) / top, bar.size.y), Color(0.02, 0.84, 0.63, 0.45))
	var now := rate(1.0 if phase == "faster" else 2.0)
	var x := bar.position.x + bar.size.x * clampf(now / top, 0.0, 1.0)
	canvas.draw_rect(Rect2(x - 1, bar.position.y - 2, 2, bar.size.y + 4), WHITE)
	text(canvas, Vector2(side / 2.0, side - 20), tr("%.1f taps/s") % now, WHITE)


func _draw_rhythm(canvas: CanvasItem) -> void:
	var left := 14.0
	var width := side - 28.0
	var y := 12.0
	var since := time - origin()
	var bar_progress := fmod(maxf(since, 0.0), _beat * 4.0) / (_beat * 4.0)
	canvas.draw_line(Vector2(left, y), Vector2(left + width, y), Color(1, 1, 1, 0.2), 1.0)
	for b in 4:
		canvas.draw_line(Vector2(left + width * b / 4.0, y - 3), Vector2(left + width * b / 4.0, y + 3), Color(1, 1, 1, 0.3), 1.0)
	for p in rhythm:
		canvas.draw_circle(Vector2(left + width * float(p) / 4.0, y), 2.5, GOLD)
	if since >= 0.0:
		var x := left + width * bar_progress
		canvas.draw_line(Vector2(x, y - 5), Vector2(x, y + 5), WHITE, 1.0)
