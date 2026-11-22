extends SceneTree
## Headless tests for the fight-box modes. Run from the repo root:
##   godot --headless --path game -s res://tests/test_fight_modes.gd
## Each mode is driven with scripted "fingers" to check that good play fills
## the catch meter and bad play drains it. Exits with code 1 on failure.

const SIDE := 120.0
const DT := 1.0 / 60.0

var _failures := 0


func _init() -> void:
	_test_catalog()
	_test_every_mode_runs()
	_test_slide_guide()
	_test_hold_hop()
	_test_twin_drift()
	_test_beat_notes()
	_test_tap_tempo()
	_test_lost_ref()
	_test_shake_rub()
	_test_reel_spin()
	_test_flick_hookset()
	_test_session()
	_test_difficulty()
	if _failures == 0:
		print("All fight mode tests passed.")
	quit(1 if _failures > 0 else 0)


func _test_catalog() -> void:
	var entries := FightCatalog.entries()
	_check(entries.size() >= 9, "catalog lists at least 9 modes")
	var ids := {}
	for e in entries:
		for key in ["id", "name", "script", "fingers", "hint", "tuning"]:
			_check(e.has(key), "%s has '%s'" % [e.get("id", "?"), key])
		_check(not ids.has(e.id), "%s id is unique" % e.id)
		ids[e.id] = true
		_check(int(e.fingers) >= 1 and int(e.fingers) <= 2, "%s uses 1 or 2 fingers" % e.id)
		var pairs := 0
		for key in e.tuning:
			var v: Variant = e.tuning[key]
			if v is Array:
				pairs += 1
				_check(v.size() == 2 and typeof(v[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(v[1]) in [TYPE_INT, TYPE_FLOAT], "%s %s is an [easy, hard] pair of numbers" % [e.id, key])
		_check(pairs >= 3, "%s has at least 3 values that change with difficulty" % e.id)
	for id in ["slide_guide", "hold_hop", "twin_drift", "beat_notes", "tap_tempo", "lost_ref", "shake_rub"]:
		_check(ids.has(id), "catalog has %s" % id)


## Every mode survives a minute of random poking without errors, keeps its
## judgement totals sane and respects its finger count.
func _test_every_mode_runs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for e in FightCatalog.entries():
		var mode := FightCatalog.create(e.id, SIDE, {"seed": 3})
		_check(mode != null, "%s builds" % e.id)
		if mode == null:
			continue
		_check(mode.max_fingers() == int(e.fingers), "%s max fingers match the data" % e.id)
		var total := 0.0
		var down := false
		var at := Vector2(60, 60)
		for f in 3600:
			if f % 20 == 0:
				down = not down
				at = Vector2(rng.randf_range(0, SIDE), rng.randf_range(0, SIDE))
				total += mode.touch(0, at, down)
			if mode.uses_motion():
				mode.motion(Vector3(rng.randf_range(-15, 15), 9.8, 0), true)
			total += mode.step(DT, {0: at} if down else {})
		var j := mode.take_judgement()
		_check(is_finite(total), "%s meter changes are finite" % e.id)
		_check(j.y > 0.0 and j.x >= 0.0 and j.x <= j.y + 0.001, "%s judgement totals are sane" % e.id)


func _test_slide_guide() -> void:
	var on := FightCatalog.create("slide_guide", SIDE, {"seed": 1})
	var off := FightCatalog.create("slide_guide", SIDE, {"seed": 1})
	var gained := 0.0
	var lost := 0.0
	for f in 300:
		gained += on.step(DT, {0: on.target()})
		lost += off.step(DT, {0: Vector2(-50, -50)})
	_check(gained > 0.3, "slide guide: staying on the ring fills the meter")
	_check(lost < -0.3, "slide guide: missing the ring drains it")


func _test_hold_hop() -> void:
	# Perfect play: press on the spot on time, hold, lift on time.
	var mode := FightCatalog.create("hold_hop", SIDE, {"seed": 2})
	var total := 0.0
	for spot_n in 3:
		while mode.time < mode.press_at:
			total += mode.step(DT, {})
		var spot: Vector2 = mode.spot
		total += mode.touch(0, spot, true)
		_check(mode.state == mode.State.HOLD, "hold hop: an on-time press starts the hold")
		while mode.hold_progress() < 1.0:
			total += mode.step(DT, {0: spot})
		total += mode.touch(0, spot, false)
	_check(total > 0.3, "hold hop: clean presses and lifts fill the meter")
	# Lifting too soon costs a timing miss.
	var early := FightCatalog.create("hold_hop", SIDE, {"seed": 2})
	while early.time < early.press_at:
		early.step(DT, {})
	var press := early.touch(0, early.spot, true)
	early.step(DT, {0: early.spot})
	var lift := early.touch(0, early.spot, false)
	_check(lift <= -0.1, "hold hop: lifting too soon is punished")
	# Aim matters less than timing: an off-centre on-time press still pays.
	var off_centre := FightCatalog.create("hold_hop", SIDE, {"seed": 2})
	while off_centre.time < off_centre.press_at:
		off_centre.step(DT, {})
	var aimed := off_centre.touch(0, off_centre.spot + Vector2(6, 0), true)
	_check(aimed > 0.0 and aimed < press, "hold hop: an off-centre press pays less but still pays")
	# Wandering out of the spot breaks the hold.
	var slip := FightCatalog.create("hold_hop", SIDE, {"seed": 2})
	while slip.time < slip.press_at:
		slip.step(DT, {})
	slip.touch(0, slip.spot, true)
	var drift := 0.0
	for f in 40:
		drift += slip.step(DT, {0: slip.spot + Vector2(30, 0)})
	_check(drift <= -0.1, "hold hop: leaving the spot too long breaks the hold")


func _test_twin_drift() -> void:
	var both := FightCatalog.create("twin_drift", SIDE, {"seed": 4})
	var none := FightCatalog.create("twin_drift", SIDE, {"seed": 4})
	var gained := 0.0
	var lost := 0.0
	var max_dy := 0.0
	var min_gap := INF
	for f in 600:
		gained += both.step(DT, {0: both.boxes[0], 1: both.boxes[1]})
		lost += none.step(DT, {})
		max_dy = maxf(max_dy, absf(both.boxes[0].y - both.boxes[1].y))
		min_gap = minf(min_gap, both.boxes[1].x - both.boxes[0].x)
	_check(gained > 0.5, "twin drift: two fingers on two squares fill the meter")
	_check(lost < -0.5, "twin drift: no fingers drains it")
	_check(max_dy <= 30.5, "twin drift: squares stay within one hand's vertical reach")
	_check(min_gap >= 20.0, "twin drift: squares stay a finger-width apart")


func _test_beat_notes() -> void:
	var mode := FightCatalog.create("beat_notes", SIDE, {"seed": 5})
	var total := 0.0
	var hits := 0
	while mode.time < 12.0:
		var n: Dictionary = mode.next_note()
		if not n.is_empty() and n.kind == "tap" and absf(mode.time - n.t) <= 0.01:
			total += mode.touch(0, n.pos, true)
			total += mode.touch(0, n.pos, false)
			hits += 1
		total += mode.step(DT, {})
	_check(hits >= 6, "beat notes: generated tap notes to hit")
	var idle := FightCatalog.create("beat_notes", SIDE, {"seed": 5})
	var idle_total := 0.0
	while idle.time < 12.0:
		idle_total += idle.step(DT, {})
	_check(idle_total < -0.3, "beat notes: ignoring notes drains the meter")
	# A tap far too early on a note is a miss.
	var early := FightCatalog.create("beat_notes", SIDE, {"seed": 5})
	var first: Dictionary = early.next_note()
	while early.time < first.t - 0.3:
		early.step(DT, {})
	_check(early.touch(0, first.pos, true) < 0.0, "beat notes: a too-early tap is a miss")
	_check(total > idle_total, "beat notes: hitting notes beats ignoring them")


func _test_tap_tempo() -> void:
	var mode := FightCatalog.create("tap_tempo", SIDE, {"seed": 6, "phase_time": 100.0})
	var beat := 60.0 / 116.0
	var total := 0.0
	var next_tap: float = mode.origin()
	while mode.time < 5.0:
		if mode.time >= next_tap:
			total += mode.touch(0, Vector2(60, 60), true)
			total += mode.touch(0, Vector2(60, 60), false)
			next_tap += beat
		total += mode.step(DT, {})
	_check(mode.phase == "steady", "tap tempo: starts with a steady beat")
	_check(total > 0.1, "tap tempo: tapping on the beat fills the meter")
	var silent := FightCatalog.create("tap_tempo", SIDE, {"seed": 6, "phase_time": 100.0})
	var silent_total := 0.0
	while silent.time < 5.0:
		silent_total += silent.step(DT, {})
	_check(silent_total < -0.1, "tap tempo: missing beats drains it")


func _test_lost_ref() -> void:
	var mode := FightCatalog.create("lost_ref", SIDE, {"seed": 8, "every_min": 2.0, "every_max": 2.0, "warn": 1.0, "top_min": 3.0, "top_max": 3.0, "back": 1.0})
	var P := FightMode.Pads
	_check(mode.pads() == P.NORMAL, "lost ref: starts with both boxes working")
	var seen: Array = [mode.pads()]
	var gained_top := 0.0
	var cued := true
	while mode.time < 7.5:
		var fingers := {0: mode.inner.target()}
		var change := mode.step(DT, fingers)
		if mode.pads() == P.TOP_ONLY:
			gained_top += change
		if mode.pads() != P.NORMAL and mode.cue == "":
			cued = false
		if mode.pads() != seen[-1]:
			seen.append(mode.pads())
	_check(seen.slice(0, 5) == [P.NORMAL, P.WARN_UP, P.TOP_ONLY, P.BACK_DOWN, P.NORMAL], "lost ref: warn, top box only, back down, normal, in that order")
	_check(gained_top > 0.0, "lost ref: playing in the top box still fills the meter")
	_check(cued, "lost ref: every box change comes with a cue")


func _test_shake_rub() -> void:
	# With a sensor: shaking during SHAKE fills.
	var mode := FightCatalog.create("shake_rub", SIDE, {"seed": 9, "shake_min": 100.0, "shake_max": 100.0})
	var total := 0.0
	for f in 120:
		mode.motion(Vector3(20.0 if f % 2 == 0 else -20.0, 9.8, 0), true)
		total += mode.step(DT, {})
	_check(mode.has_sensor, "shake: sees the sensor")
	_check(total > 0.05, "shake: shaking on SHAKE fills the meter")
	# Without a sensor: rubbing back and forth fills, a still finger doesn't.
	var rub := FightCatalog.create("shake_rub", SIDE, {"seed": 9, "shake_min": 100.0, "shake_max": 100.0})
	var rubbed := 0.0
	for f in 180:
		rub.motion(Vector3.ZERO, false)
		var x := 60.0 + 30.0 * sin(f * 0.6)
		rubbed += rub.step(DT, {0: Vector2(x, 60)})
	_check(not rub.has_sensor, "shake: falls back to rubbing without a sensor")
	_check(rubbed > 0.05, "shake: rubbing back and forth fills the meter")
	var still := FightCatalog.create("shake_rub", SIDE, {"seed": 9, "shake_min": 100.0, "shake_max": 100.0})
	var held := 0.0
	for f in 180:
		still.motion(Vector3.ZERO, false)
		held += still.step(DT, {0: Vector2(60, 60)})
	_check(held < 0.0, "shake: a still finger doesn't count as rubbing")


func _test_reel_spin() -> void:
	var mode := FightCatalog.create("reel_spin", SIDE, {"seed": 10, "reel_min": 100.0, "reel_max": 100.0})
	var total := 0.0
	var a := 0.0
	for f in 240:
		a += TAU * 1.5 * DT  # 1.5 turns a second, clockwise on screen
		total += mode.step(DT, {0: mode.center() + Vector2.from_angle(a) * 35.0})
	_check(total > 0.1, "reel spin: steady clockwise spinning reels in")
	# Touch updates only every third frame (slow phones, browsers) still read as spinning.
	var sparse := FightCatalog.create("reel_spin", SIDE, {"seed": 10, "reel_min": 100.0, "reel_max": 100.0})
	var sparse_total := 0.0
	var at := sparse.center() + Vector2(35, 0)
	a = 0.0
	for f in 240:
		a += TAU * 1.5 * DT
		if f % 3 == 0:
			at = sparse.center() + Vector2.from_angle(a) * 35.0
		sparse_total += sparse.step(DT, {0: at})
	_check(sparse_total > 0.1, "reel spin: works when touches update less often than frames")
	var wrong := FightCatalog.create("reel_spin", SIDE, {"seed": 10, "reel_min": 100.0, "reel_max": 100.0})
	var lost := 0.0
	a = 0.0
	for f in 240:
		a -= TAU * 1.5 * DT
		lost += wrong.step(DT, {0: wrong.center() + Vector2.from_angle(a) * 35.0})
	_check(lost < 0.0, "reel spin: spinning the wrong way loses line")
	var fast := FightCatalog.create("reel_spin", SIDE, {"seed": 10, "reel_min": 100.0, "reel_max": 100.0})
	var snapped := false
	a = 0.0
	for f in 400:
		a += TAU * 4.0 * DT
		if fast.step(DT, {0: fast.center() + Vector2.from_angle(a) * 35.0}) <= -0.2:
			snapped = true
	_check(snapped, "reel spin: spinning far too fast snaps the line")


func _test_flick_hookset() -> void:
	var mode := FightCatalog.create("flick_hookset", SIDE, {"seed": 11, "decoy_chance": 0.0})
	while mode.time < mode.go_at:
		mode.step(DT, {})
	var start := Vector2(60, 60)
	mode.touch(0, start, true)
	mode.step(DT, {0: start})
	var good := mode.touch(0, start + mode.cue_dir * 30.0, false)
	_check(good > 0.0, "hookset: an on-time flick the right way hooks")
	var wrong := FightCatalog.create("flick_hookset", SIDE, {"seed": 11, "decoy_chance": 0.0})
	while wrong.time < wrong.go_at:
		wrong.step(DT, {})
	wrong.touch(0, start, true)
	wrong.step(DT, {0: start})
	_check(wrong.touch(0, start - wrong.cue_dir * 30.0, false) < 0.0, "hookset: flicking the wrong way is a miss")
	var slow := FightCatalog.create("flick_hookset", SIDE, {"seed": 11, "decoy_chance": 0.0})
	while slow.time < slow.go_at:
		slow.step(DT, {})
	slow.touch(0, start, true)
	for f in 60:
		slow.step(DT, {0: start})
	_check(slow.touch(0, start + slow.cue_dir * 30.0, false) == 0.0, "hookset: a slow drag is not a flick")


func _test_difficulty() -> void:
	var easy := FightCatalog.create("slide_guide", SIDE, {"seed": 1}, 0.0)
	var middle := FightCatalog.create("slide_guide", SIDE, {"seed": 1}, 0.5)
	var hard := FightCatalog.create("slide_guide", SIDE, {"seed": 1}, 1.0)
	_check(is_equal_approx(easy.num("radius", 0), 16.0) and is_equal_approx(hard.num("radius", 0), 9.0), "difficulty: [easy, hard] pairs give the ends at 0 and 1")
	_check(is_equal_approx(middle.num("radius", 0), 12.5), "difficulty: the middle blends the pair")
	_check(is_equal_approx(easy.num("missing", 3.0), 3.0), "difficulty: missing keys use the fallback")
	# A finger trailing 12 px behind the ring: still on it when easy, off it when hard.
	var easy_total := 0.0
	var hard_total := 0.0
	for f in 300:
		easy_total += easy.step(DT, {0: easy.target() + Vector2(12, 0)})
		hard_total += hard.step(DT, {0: hard.target() + Vector2(12, 0)})
	_check(easy_total > 0.0 and hard_total < 0.0, "difficulty: the same play passes on easy and fails on hard")
	var lost_ref := FightCatalog.create("lost_ref", SIDE, {"seed": 2}, 0.9)
	_check(is_equal_approx(lost_ref.inner.difficulty, 0.9), "difficulty: Lost Ref passes its difficulty to the inner mode")
	# Every mode runs at both ends without errors.
	for e in FightCatalog.entries():
		for d in [0.0, 1.0]:
			var mode := FightCatalog.create(e.id, SIDE, {"seed": 4}, d)
			var total := 0.0
			for f in 600:
				total += mode.step(DT, {0: Vector2(60, 60)} if f % 40 < 20 else {})
			_check(is_finite(total), "%s runs at difficulty %d" % [e.id, int(d * 10)])


func _test_session() -> void:
	var s := FightSession.new()
	_check(s.add(0.5) == 0, "session: partial progress is neither catch nor escape")
	s.tick(4.0)
	_check(s.add(0.5) == 1 and s.catches == 1, "session: reaching the top is a catch")
	_check(is_equal_approx(s.average_catch_time(), 4.0), "session: catch time is recorded")
	_check(is_equal_approx(s.progress, FightSession.START), "session: the meter resets after a catch")
	_check(s.add(-1.0) == -1 and s.escapes == 1, "session: hitting zero is an escape")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)
