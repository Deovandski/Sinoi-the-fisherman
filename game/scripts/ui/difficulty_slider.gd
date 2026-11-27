class_name DifficultySlider
extends Control
## "Easy ---o--- Hard" slider with whole steps (0..MAX). Drag the knob or
## tap anywhere on the track. `changed` fires when the finger lifts, so the
## fight restarts once, not on every step of a drag.

signal changed(level: int)

const MAX := 10
const FONT_SIZE := 7

var level := 5
var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_level(value: int) -> void:
	level = clampi(value, 0, MAX)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_move_to(event.position.x)
		elif _dragging:
			_dragging = false
			_move_to(event.position.x)
			changed.emit(level)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_move_to(event.position.x)
		accept_event()


func _move_to(x: float) -> void:
	var track := _track()
	var value := roundi(clampf((x - track.x) / (track.y - track.x), 0.0, 1.0) * MAX)
	if value != level:
		level = value
		queue_redraw()


## Track's left and right x.
func _track() -> Vector2:
	var font := ThemeDB.fallback_font
	var left := font.get_string_size(tr("Easy"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 8.0
	var right := font.get_string_size(tr("Hard") + " 10", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 8.0
	return Vector2(left, size.x - right)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var cy := size.y / 2.0
	var track := _track()
	var baseline := cy + FONT_SIZE / 2.0 - 1.0
	draw_string(font, Vector2(2, baseline), tr("Easy"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color("06d6a0"))
	var t := float(level) / MAX
	var color := Color("06d6a0").lerp(Color("ffd166"), minf(t * 2.0, 1.0)).lerp(Color("ef476f"), maxf(t * 2.0 - 1.0, 0.0))
	draw_string(font, Vector2(track.y + 6.0, baseline), tr("Hard"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color("ef476f"))
	var value := str(level)
	var value_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(size.x - 2.0 - value_width, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
	draw_rect(Rect2(track.x, cy - 1.0, track.y - track.x, 2.0), Color("23415a"))
	draw_rect(Rect2(track.x, cy - 1.0, (track.y - track.x) * t, 2.0), color)
	for i in MAX + 1:
		var x := roundf(lerpf(track.x, track.y, float(i) / MAX))
		draw_rect(Rect2(x, cy + 2.0, 1.0, 2.0 if i % 5 == 0 else 1.0), Color("3d6680"))
	var kx := roundf(lerpf(track.x, track.y, t))
	draw_rect(Rect2(kx - 2.0, cy - 4.0, 5.0, 8.0), color)
	draw_rect(Rect2(kx - 2.0, cy - 4.0, 5.0, 8.0), Color("0d1b2a"), false, 1.0)
