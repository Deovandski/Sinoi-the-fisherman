extends FightMode
## Flip: runs another mode (Slide Guide by default) and every few seconds
## swaps the two boxes and turns them upside down, so the player has to
## play in the top box and read the bottom one. A warning blinks first.
## The host does the swap and the touch mapping; this only keeps the clock.

var inner: FightMode
var _flipped := false
var _next := 0.0


func _start() -> void:
	inner = FightCatalog.create(str(tuning.get("inner", "slide_guide")), side, {"seed": rng.randi()})
	_next = _interval()


func max_fingers() -> int:
	return inner.max_fingers()


func uses_motion() -> bool:
	return inner.uses_motion()


func is_flipped() -> bool:
	return _flipped


func flip_warning() -> float:
	var left := _next - time
	return left if left <= num("warn", 1.2) else -1.0


func _step(delta: float, fingers: Dictionary) -> float:
	if time >= _next:
		_flipped = not _flipped
		_next = time + _interval()
		sfx("tock")
		pop(center(), "FLIP!", GOLD)
	var change := inner.step(delta, fingers)
	var j := inner.take_judgement()
	judge(j.x / j.y if j.y > 0.0 else 0.0, j.y)
	sounds.append_array(inner.sounds)
	inner.sounds.clear()
	var warning := flip_warning()
	if warning >= 0.0:
		cue = "Flip in %d..." % ceili(warning)
	elif inner.cue != "":
		cue = inner.cue
	else:
		cue = "Play in the TOP box" if _flipped else ""
	return change


func touch(index: int, at: Vector2, pressed: bool) -> float:
	return inner.touch(index, at, pressed)


func motion(acceleration: Vector3, available: bool) -> void:
	inner.motion(acceleration, available)


func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	inner.draw_pad(canvas, shadow)


func _interval() -> float:
	return rng.randf_range(num("every_min", 6.0), num("every_max", 10.0))
