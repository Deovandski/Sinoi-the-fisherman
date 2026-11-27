extends FightMode
## Twin Drift: two squares, one in each half of the pad, for the index and
## middle finger of one hand. Each drifts up, down, left and right on its
## own path, and their speeds swell and ease out of step with each other.
##
## One-hand limits (finger "enslaving" research: neighbouring fingers can
## only move independently over a small range) are built in: the squares
## never sit more than `max_dy` apart vertically and keep at least
## `min_gap` apart sideways.

var boxes: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var on_box: Array[bool] = [false, false]
var _phase: Array[float] = [0.0, 0.0]
var _seeds: Array[float] = []


func _start() -> void:
	for i in 6:
		_seeds.append(rng.randf_range(0.0, TAU))
	_move(0.0)


func max_fingers() -> int:
	return 2


func _step(delta: float, fingers: Dictionary) -> float:
	_move(delta)
	_assign(fingers.values())
	var count := int(on_box[0]) + int(on_box[1])
	judge(count / 2.0, delta)
	match count:
		2:
			cue = ""
			return num("fill", 0.1) * delta
		1:
			cue = tr("Both squares!")
			return -num("one_drain", 0.03) * delta
		_:
			cue = tr("Index + middle finger") if fingers.is_empty() else tr("Find the squares")
			return -num("drain", 0.1) * delta


func _move(delta: float) -> void:
	var half_box := num("half", 10.0)
	var lane := side / 2.0
	for i in 2:
		# Each square has its own speed curve, so they drift in and out of sync.
		var swell := 0.55 + 0.45 * sin(time * (0.21 + 0.09 * i) + _seeds[i])
		_phase[i] += delta * num("speed", 1.0) * (0.5 + swell)
		var a := _phase[i]
		var x := lane * (0.5 + i) + sin(a * 1.1 + _seeds[2 + i]) * (lane / 2.0 - half_box - 3.0)
		var y := side / 2.0 + sin(a * 0.8 + _seeds[4 + i % 2] + i) * (side / 2.0 - half_box - 4.0)
		boxes[i] = Vector2(x, y)
	# One-hand limits: keep the squares a finger-width apart and not too far
	# apart vertically (the right one follows the left).
	var dy := boxes[1].y - boxes[0].y
	var max_dy := num("max_dy", 30.0)
	if absf(dy) > max_dy:
		boxes[1].y = boxes[0].y + signf(dy) * max_dy
	var gap := boxes[1].x - boxes[0].x
	if gap < num("min_gap", 28.0):
		var push := (num("min_gap", 28.0) - gap) / 2.0
		boxes[0].x -= push
		boxes[1].x += push
	for i in 2:
		boxes[i] = clamp_in_pad(boxes[i], half_box + 2.0)


## Matches fingers to squares: with two fingers the left one takes the left
## square; a lone finger counts for whichever square it is on.
func _assign(points: Array) -> void:
	on_box = [false, false]
	var sorted := points.duplicate()
	sorted.sort_custom(func(a, b): return a.x < b.x)
	if sorted.size() >= 2:
		on_box[0] = _inside(sorted[0], 0)
		on_box[1] = _inside(sorted[1], 1)
	elif sorted.size() == 1:
		on_box[0] = _inside(sorted[0], 0)
		on_box[1] = _inside(sorted[0], 1)


func _inside(p: Vector2, i: int) -> bool:
	var reach := num("half", 10.0) + 3.0
	return absf(p.x - boxes[i].x) <= reach and absf(p.y - boxes[i].y) <= reach


func _draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	var h := num("half", 10.0)
	if shadow:
		canvas.draw_line(Vector2(side / 2.0, 2), Vector2(side / 2.0, side - 2), Color(1, 1, 1, 0.08), 1.0)
	for i in 2:
		var rect := Rect2(boxes[i] - Vector2(h, h), Vector2(h, h) * 2.0)
		var color: Color = [GOLD, GREEN][i]
		if shadow:
			canvas.draw_rect(rect, Color(color, 0.45 if on_box[i] else 0.2))
			canvas.draw_rect(rect, color, false, 1.0)
		else:
			canvas.draw_rect(rect, Color(color, 0.5), false, 1.0)
