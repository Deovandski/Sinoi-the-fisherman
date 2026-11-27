extends FightMode
## Slide Guide: keep one finger on a ring that wanders around the pad
## (Stardew's bar turned into a 2D trace). The first prototype, now the
## baseline the other modes are compared with. Its speed slowly swells and
## eases so the fish feels alive.

var _phase := 0.0


func target() -> Vector2:
	var half := side / 2.0
	var reach := half - num("radius", 12.0) - 4.0
	return Vector2(half + sin(_phase * 1.3) * reach, half + sin(_phase * 0.9 + 1.0) * reach)


func _step(delta: float, fingers: Dictionary) -> float:
	var speed := num("speed", 1.0) * (1.0 + num("speed_wobble", 0.35) * sin(time * 0.37))
	_phase += delta * speed
	var on := false
	for p in fingers.values():
		if p.distance_to(target()) <= num("radius", 12.0):
			on = true
	judge(1.0 if on else 0.0, delta)
	cue = "" if on or fingers.is_empty() else tr("Back on the ring!")
	return (num("fill", 0.12) if on else -num("drain", 0.1)) * delta


func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	var r := num("radius", 12.0)
	if shadow:
		canvas.draw_circle(target(), r, Color(1, 0.82, 0.4, 0.35))
		ring(canvas, target(), r, GOLD)
	else:
		ring(canvas, target(), r, FAINT)
