extends Control
## Fight-box touch test (placeholder).
##
## Two pads, as decided in docs/white-paper/02-design-direction.md:
## - the interactive pad at the bottom, where fingers go;
## - the shadow pad above it, mirroring the target and every finger, so the
##   player can watch it while their fingers cover the real pad.
## Keep a finger on the moving target to fill the catch meter. Up to two
## fingers are tracked and drawn (more are shown but don't count).

const MAX_COUNTED_FINGERS := 2
const TARGET_RADIUS := 12.0
const FILL_PER_SECOND := 0.28
const DRAIN_PER_SECOND := 0.16
const FINGER_COLORS := [Color("ffd166"), Color("06d6a0"), Color("ef476f"), Color("118ab2"), Color("ffffff")]

var _touches := {}  # index -> Vector2 in this control's coordinates
var _time := 0.0
var _progress := 0.0
var _catches := 0
var _info: Label


func _ready() -> void:
	theme = UiTheme.build()
	var back := Button.new()
	back.text = "< Back"
	back.position = Vector2(4, 4)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	add_child(back)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 8)
	_info.position = Vector2(60, 7)
	add_child(_info)


func _process(delta: float) -> void:
	_time += delta
	var on_target := false
	var target := _target_in_pad()
	var counted := 0
	for index in _touches.keys():
		if counted >= MAX_COUNTED_FINGERS:
			break
		counted += 1
		var local: Vector2 = _touches[index] - _pad_rect().position
		if local.distance_to(target) <= TARGET_RADIUS:
			on_target = true
	_progress += (FILL_PER_SECOND if on_target else -DRAIN_PER_SECOND) * delta
	_progress = clampf(_progress, 0.0, 1.0)
	if _progress >= 1.0:
		_catches += 1
		_progress = 0.0
	_info.text = "Fingers: %d   Caught: %d" % [_touches.size(), _catches]
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var local_event := make_input_local(event) as InputEventScreenTouch
		if event.pressed:
			_touches[event.index] = local_event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		var local_drag := make_input_local(event) as InputEventScreenDrag
		_touches[event.index] = local_drag.position


# --- Layout -----------------------------------------------------------------

func _pad_side() -> float:
	return floorf(minf(size.x - 20.0, (size.y - 90.0) / 2.0))


func _pad_rect() -> Rect2:
	var side := _pad_side()
	return Rect2(Vector2(floorf((size.x - side) / 2.0), size.y - side - 16.0), Vector2(side, side))


func _shadow_rect() -> Rect2:
	var side := _pad_side()
	return Rect2(Vector2(floorf((size.x - side) / 2.0), 26.0), Vector2(side, side))


## Target position inside a pad, in pad-local coordinates.
func _target_in_pad() -> Vector2:
	var side := _pad_side()
	var half := side / 2.0
	var reach := half - TARGET_RADIUS - 4.0
	return Vector2(half + sin(_time * 1.3) * reach, half + sin(_time * 0.9 + 1.0) * reach)


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d1b2a"))
	var pad := _pad_rect()
	var shadow := _shadow_rect()
	var target := _target_in_pad()

	# Shadow pad: full visuals.
	draw_rect(shadow, Color("16324a"))
	draw_rect(shadow, Color("6fa3c0"), false, 1.0)
	draw_circle(shadow.position + target, TARGET_RADIUS, Color(1, 0.82, 0.4, 0.35))
	draw_arc(shadow.position + target, TARGET_RADIUS, 0, TAU, 24, Color("ffd166"), 1.0)

	# Interactive pad: minimal visuals (fingers cover it anyway).
	draw_rect(pad, Color("102536"))
	draw_rect(pad, Color("3d6680"), false, 1.0)
	draw_arc(pad.position + target, TARGET_RADIUS, 0, TAU, 24, Color(1, 0.82, 0.4, 0.5), 1.0)

	# Fingers: drawn on the real pad and mirrored as ghost dots on the shadow.
	var i := 0
	for index in _touches.keys():
		var color: Color = FINGER_COLORS[min(i, FINGER_COLORS.size() - 1)]
		var at: Vector2 = _touches[index]
		draw_circle(at, 5.0, color)
		var mirrored := shadow.position + (at - pad.position)
		if shadow.has_point(mirrored):
			draw_circle(mirrored, 4.0, Color(color, 0.8))
		i += 1

	# Catch meter between the pads.
	var meter := Rect2(Vector2(pad.position.x, shadow.end.y + 6.0), Vector2(pad.size.x, 6.0))
	draw_rect(meter, Color("23415a"))
	draw_rect(Rect2(meter.position, Vector2(meter.size.x * _progress, meter.size.y)), Color("06d6a0"))
	draw_rect(meter, Color("6fa3c0"), false, 1.0)
