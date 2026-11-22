class_name ModeCarousel
extends Control
## A one-row carousel of names: the chosen one sits in the middle, its
## neighbours peek in from the sides. Swipe it, tap a neighbour, or tap the
## arrows at either end. Works with touch (through mouse emulation) and mouse.

signal selected(index: int)

const FONT_SIZE := 8
const PAD := 5.0
const GAP := 4.0
const ARROW := 12.0
const TAP_SLOP := 4.0

var names: PackedStringArray = []
var current := 0
var _offset := 0.0
var _press_x := -1.0
var _press_offset := 0.0
var _dragging := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func(): _offset = _target_offset())


func set_names(list: PackedStringArray, index := 0) -> void:
	names = list
	current = clampi(index, 0, maxi(list.size() - 1, 0))
	_offset = _target_offset()
	queue_redraw()


func select(index: int, notify := true) -> void:
	if names.is_empty():
		return
	current = posmod(index, names.size())
	if notify:
		selected.emit(current)
	queue_redraw()


func _process(delta: float) -> void:
	if _dragging:
		return
	var target := _target_offset()
	if absf(_offset - target) > 0.25:
		_offset = lerpf(_offset, target, 1.0 - exp(-14.0 * delta))
		queue_redraw()
	elif _offset != target:
		_offset = target
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_x = event.position.x
			_press_offset = _offset
			_dragging = false
		elif _press_x >= 0.0:
			if _dragging:
				select(_nearest_to_middle())
			else:
				_tap(event.position.x)
			_press_x = -1.0
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _press_x >= 0.0:
		var dx: float = event.position.x - _press_x
		if absf(dx) > TAP_SLOP:
			_dragging = true
		if _dragging:
			_offset = _press_offset - dx
			queue_redraw()
		accept_event()


func _tap(x: float) -> void:
	if x < ARROW:
		select(current - 1)
		return
	if x > size.x - ARROW:
		select(current + 1)
		return
	for i in names.size():
		var span := _span(i)
		if x >= span.x - _offset and x <= span.y - _offset:
			if i != current:
				select(i)
			return


## Chip i's left and right edge in strip coordinates.
func _span(i: int) -> Vector2:
	var x := 0.0
	for k in i:
		x += _width(k) + GAP
	return Vector2(x, x + _width(i))


func _width(i: int) -> float:
	return ThemeDB.fallback_font.get_string_size(names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + PAD * 2.0


func _target_offset() -> float:
	if names.is_empty():
		return 0.0
	var span := _span(current)
	return (span.x + span.y) / 2.0 - size.x / 2.0


func _nearest_to_middle() -> int:
	var best := current
	var best_distance := INF
	for i in names.size():
		var span := _span(i)
		var d := absf((span.x + span.y) / 2.0 - _offset - size.x / 2.0)
		if d < best_distance:
			best_distance = d
			best = i
	return best


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1622"))
	for i in names.size():
		var span := _span(i)
		var rect := Rect2(span.x - _offset, 1.0, span.y - span.x, size.y - 2.0)
		if rect.end.x < 0.0 or rect.position.x > size.x:
			continue
		var chosen := i == current
		draw_rect(rect, Color("23415a") if chosen else Color("142a3b"))
		draw_rect(rect, Color("ffd166") if chosen else Color("3d6680"), false, 1.0)
		draw_string(font, Vector2(rect.position.x + PAD, rect.position.y + rect.size.y / 2.0 + FONT_SIZE / 2.0 - 1.0), names[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color("f3e3b3") if chosen else Color("9fc3d6"))
	# Arrows over the strip so chips slide under them.
	for left in [true, false]:
		var box := Rect2(0.0 if left else size.x - ARROW, 0.0, ARROW, size.y)
		draw_rect(box, Color("0a1622"))
		var cx := box.position.x + ARROW / 2.0
		var cy := size.y / 2.0
		var d := 1.0 if left else -1.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 2.0 * d, cy), Vector2(cx + 2.0 * d, cy - 3.0), Vector2(cx + 2.0 * d, cy + 3.0)]), Color("ffd166"))
