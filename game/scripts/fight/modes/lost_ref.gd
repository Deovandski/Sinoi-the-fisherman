extends FightMode
## Lost Ref: runs another mode (Slide Guide by default) and every so often
## takes the reference box away. Deovandski's design (2026-11-22):
## 1. Both boxes pulse as a warning.
## 2. The bottom box goes out (red, arrow pointing up). The top box is the
##    only one left: play in it, with no separate reference box.
## 3. Warning again: the top box flashes yellow and the red bottom box
##    shows an arrow pointing down. For about a second the player is back
##    in the bottom box with no reference.
## 4. The top box returns as the reference and play is normal again.
## The host moves input between the boxes and draws the red-out, arrows and
## flashes; this only keeps the clock.

var inner: FightMode
var state := Pads.NORMAL
var _until := 0.0


func _start() -> void:
	inner = FightCatalog.create(str(tuning.get("inner", "slide_guide")), side, {"seed": rng.randi()}, difficulty)
	_until = _normal_time()


func max_fingers() -> int:
	return inner.max_fingers()


func uses_motion() -> bool:
	return inner.uses_motion()


func pads() -> Pads:
	return state


func _step(delta: float, fingers: Dictionary) -> float:
	if time >= _until:
		_advance()
	var change := inner.step(delta, fingers)
	var j := inner.take_judgement()
	judge(j.x / j.y if j.y > 0.0 else 0.0, j.y)
	sounds.append_array(inner.sounds)
	inner.sounds.clear()
	match state:
		Pads.WARN_UP:
			cue = "Bottom box going out!"
		Pads.TOP_ONLY:
			cue = "Play in the TOP box" if inner.cue == "" else inner.cue
		Pads.BACK_DOWN:
			cue = "Back to the bottom box!"
		_:
			cue = inner.cue
	return change


func _advance() -> void:
	match state:
		Pads.NORMAL:
			state = Pads.WARN_UP
			_until = time + num("warn", 1.2)
			sfx("tick")
		Pads.WARN_UP:
			state = Pads.TOP_ONLY
			_until = time + rng.randf_range(num("top_min", 4.0), num("top_max", 6.0))
			sfx("tock")
		Pads.TOP_ONLY:
			state = Pads.BACK_DOWN
			_until = time + num("back", 1.0)
			sfx("tock")
		Pads.BACK_DOWN:
			state = Pads.NORMAL
			_until = time + _normal_time()


func touch(index: int, at: Vector2, pressed: bool) -> float:
	return inner.touch(index, at, pressed)


func motion(acceleration: Vector3, available: bool) -> void:
	inner.motion(acceleration, available)


func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	inner.draw_pad(canvas, shadow)


func _normal_time() -> float:
	return rng.randf_range(num("every_min", 6.0), num("every_max", 10.0))
