class_name FightStage
extends Control
## The fight box itself, shared by the fight-box test and the fish test:
## the two pads, the meter, the live cue, the intro card and banners, touch
## routing, the motion sensor and placeholder sounds.
##
## Layout (decided in docs/white-paper/02-design-direction.md):
## - the shadow pad (top) shows the full picture and ghost fingers;
## - the real pad (bottom) is where fingers go, with light outlines only;
## - the meter and the mode's live cue sit between them. The meter has one
##   segment per section (a fish can have several; the fight-box test uses one).
## The Lost Ref mode takes the top (reference) box away for a while: the
## bottom box goes out and the player plays in the top box instead.
##
## The stage doesn't know about catches: it reports meter changes and the
## screen that owns it decides what they mean.

## A meter change from the mode (per frame or from a touch).
signal changed(amount: float)
## One frame of play went by, with the judgement totals for that frame.
signal ticked(delta: float, judgement: Vector2)

const INTRO_TIME := 3.0
const BANNER_TIME := 1.2
const MIDDLE := 22.0
const FINGER_COLORS := [Color("ffd166"), Color("06d6a0"), Color("ef476f"), Color("118ab2"), Color("ffffff")]

var mode: FightMode
## Fill of each meter segment, 0..1. The screen that owns the stage sets it.
var meter: Array[float] = [0.25]
## Which segment is being played.
var meter_current := 0
## Marks where a segment starts filling (drawn as a faint tick).
var meter_start := 0.25

var _intro := {}
var _intro_left := 0.0
var _banner := ""
var _banner_left := 0.0
var _touches := {}        # touch index -> position in this control
var _pad_touches := {}    # touch indexes counted by the mode (in order)
var _sensor := MotionSensor.new()
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _side := 120.0
var _top_view: Control
var _bottom_view: Control
var _overlay: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sounds = Blip.build_all()
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		_players.append(player)
	_top_view = _make_view(true)
	_bottom_view = _make_view(false)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	resized.connect(_layout)
	_layout()


## Starts `new_mode`. With an intro ({"title", "body", "footer"}) the card
## shows first and play waits for a touch in the pad (or 3 s for modes that
## don't need touch); without one, play continues straight away.
func play(new_mode: FightMode, intro := {}) -> void:
	if mode != null:
		_release_pad_touches(false)
	mode = new_mode
	mode.side = _side
	_intro = intro
	_intro_left = INTRO_TIME if not intro.is_empty() else 0.0
	if not intro.is_empty():
		_banner_left = 0.0


func pad_side() -> float:
	return _side


func show_banner(text: String) -> void:
	_banner = text
	_banner_left = BANNER_TIME


func play_sound(sound: String) -> void:
	if not _sounds.has(sound):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _sounds[sound]
	player.play()


func sensor_available() -> bool:
	return _sensor.available()


# --- Layout ---------------------------------------------------------------------

func _make_view(top: bool) -> Control:
	var view := Control.new()
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view.bind(view, top))
	add_child(view)
	return view


func _layout() -> void:
	_side = floorf(minf(size.x - 16.0, (size.y - MIDDLE - 2.0) / 2.0))
	if mode != null:
		mode.side = _side
	_top_view.position = top_rect().position
	_top_view.size = top_rect().size
	_bottom_view.position = bottom_rect().position
	_bottom_view.size = bottom_rect().size


func top_rect() -> Rect2:
	return Rect2(Vector2(floorf((size.x - _side) / 2.0), 0.0), Vector2(_side, _side))


func bottom_rect() -> Rect2:
	return Rect2(Vector2(floorf((size.x - _side) / 2.0), _side + MIDDLE), Vector2(_side, _side))


func _active_rect() -> Rect2:
	return top_rect() if _pads() == FightMode.Pads.TOP_ONLY else bottom_rect()


func _pads() -> FightMode.Pads:
	return mode.pads() if mode != null else FightMode.Pads.NORMAL


# --- Play -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if mode == null:
		return
	var was_active := _active_rect()
	if mode.uses_motion():
		mode.motion(_sensor.read(), _sensor.available())
	if _intro_left > 0.0:
		_intro_left -= delta
	else:
		var fingers := {}
		for i in _pad_touches:
			if _touches.has(i):
				fingers[i] = _to_pad(_touches[i])
		var playing := mode
		var amount := playing.step(delta, fingers)
		ticked.emit(delta, playing.take_judgement())
		_report(amount)
		for sound in playing.sounds:
			play_sound(sound)
		playing.sounds.clear()
	_banner_left -= delta
	if _active_rect() != was_active:
		_release_pad_touches()
	queue_redraw()
	_top_view.queue_redraw()
	_bottom_view.queue_redraw()
	_overlay.queue_redraw()


func _report(amount: float) -> void:
	if amount != 0.0:
		changed.emit(amount)


func _input(event: InputEvent) -> void:
	if mode == null or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var at: Vector2 = (make_input_local(event) as InputEventScreenTouch).position
		if event.pressed:
			_touches[event.index] = at
			if _active_rect().grow(4.0).has_point(at) and _pad_touches.size() < mode.max_fingers():
				_pad_touches[event.index] = true
				_intro_left = 0.0
				_report(mode.touch(event.index, _to_pad(at), true))
		else:
			_touches[event.index] = at
			if _pad_touches.has(event.index):
				_pad_touches.erase(event.index)
				_report(mode.touch(event.index, _to_pad(at), false))
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		var to: Vector2 = (make_input_local(event) as InputEventScreenDrag).position
		_touches[event.index] = to
		# A finger slid into the box being played (Lost Ref moves play between
		# boxes, and a fish's next section starts a new mode) counts without
		# having to lift first.
		if not _pad_touches.has(event.index) and _intro_left <= 0.0 and _active_rect().has_point(to) \
				and _pad_touches.size() < mode.max_fingers():
			_pad_touches[event.index] = true
			_report(mode.touch(event.index, _to_pad(to), true))


## Stage position -> pad space of the box being played.
func _to_pad(at: Vector2) -> Vector2:
	return at - _active_rect().position


## When play moves to the other box or a new mode starts, fingers stop
## counting until they move or press again. `report` is false when the old
## mode is being replaced (its last judgement shouldn't hit the new one).
func _release_pad_touches(report := true) -> void:
	var old := mode
	var keys := _pad_touches.keys()
	_pad_touches.clear()
	for index in keys:
		if _touches.has(index):
			var amount := old.touch(index, _to_pad(_touches[index]), false)
			if report and old == mode:
				_report(amount)


# --- Drawing ----------------------------------------------------------------------

func _draw() -> void:
	var top := top_rect()
	var bar := Rect2(Vector2(top.position.x, top.end.y + 4.0), Vector2(_side, 5.0))
	var count := maxi(meter.size(), 1)
	var gap := 2.0 if count > 1 else 0.0
	var width := (bar.size.x - gap * (count - 1)) / count
	for i in count:
		var seg := Rect2(Vector2(roundf(bar.position.x + i * (width + gap)), bar.position.y), Vector2(roundf(width), bar.size.y))
		var fill := clampf(meter[i] if i < meter.size() else 0.0, 0.0, 1.0)
		draw_rect(seg, Color("23415a"))
		draw_rect(Rect2(seg.position, Vector2(seg.size.x * fill, seg.size.y)), Color("06d6a0") if i <= meter_current else Color("3d6680"))
		if i == meter_current and meter_start > 0.0:
			draw_rect(Rect2(seg.position + Vector2(roundf(seg.size.x * meter_start), 0), Vector2(1, seg.size.y)), Color(1, 1, 1, 0.3))
		draw_rect(seg, Color("ffd166") if count > 1 and i == meter_current else Color("6fa3c0"), false, 1.0)
	if mode != null and _intro_left <= 0.0:
		FightMode.text(self, Vector2(size.x / 2.0, bar.end.y + 7.0), mode.cue, Color("f3e3b3"), 8)


func _draw_view(view: Control, top: bool) -> void:
	var rect := Rect2(Vector2.ZERO, view.size)
	var pads := _pads()
	var blink := int(Time.get_ticks_msec() / 150) % 2 == 0
	view.draw_rect(rect, Color("16324a") if top else Color("102536"))
	var out := not top and pads == FightMode.Pads.TOP_ONLY      # bottom box red, arrow up
	var flashing := top and pads == FightMode.Pads.BACK_DOWN    # top box flashes yellow
	if mode != null and not out and not flashing:
		# The top box always shows the full picture (it's the reference, or the
		# only box during TOP_ONLY); the bottom box shows light outlines.
		mode.draw_pad(view, top)
	if not out:
		_draw_fingers(view, rect, top)
	if out or (not top and pads == FightMode.Pads.BACK_DOWN):
		view.draw_rect(rect, Color(0.94, 0.28, 0.44, 0.55 if out else 0.3))
		_draw_arrow(view, rect.get_center(), -1.0 if out else 1.0)
	if flashing:
		view.draw_rect(rect, Color(1, 0.82, 0.4, 0.45 if blink else 0.15))
	var border := Color("6fa3c0") if top else Color("3d6680")
	var line := 1.0
	if pads == FightMode.Pads.WARN_UP:
		# Both boxes pulse before the bottom one goes out.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 3.0)
		border = Color("3d6680").lerp(Color("ef476f"), pulse)
		line = 1.0 + roundf(pulse * 2.0)
		view.draw_rect(rect, Color(1, 1, 1, 0.08 * pulse))
	elif out:
		border = Color("ef476f")
	elif flashing:
		border = Color("ffd166")
	view.draw_rect(rect.grow(-(line - 1.0) / 2.0), border, false, line)


## Ghost fingers on the reference box, real dots on the box being played.
func _draw_fingers(view: Control, rect: Rect2, top: bool) -> void:
	var playing := (top and _pads() == FightMode.Pads.TOP_ONLY) or (not top and _pads() != FightMode.Pads.TOP_ONLY)
	var i := 0
	for index in _touches:
		var counted := _pad_touches.has(index)
		if not playing and not counted:
			continue
		var color: Color = FINGER_COLORS[mini(i, FINGER_COLORS.size() - 1)] if counted else Color(1, 1, 1, 0.35)
		var at: Vector2 = _to_pad(_touches[index]) if counted or not playing else _touches[index] - view.position
		if rect.grow(6.0).has_point(at):
			view.draw_circle(at, 5.0 if playing else 4.0, color if playing else Color(color, 0.8))
		if counted:
			i += 1


## A big arrow telling the player which box to move to (dir -1 up, 1 down).
func _draw_arrow(view: Control, at: Vector2, dir: float) -> void:
	var s := _side * 0.16
	var bob := sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.0) * 3.0 * dir
	var tip := at + Vector2(0, dir * s * 1.1 + bob)
	var base_y := tip.y - dir * s
	var color := Color("eef6fa")
	view.draw_colored_polygon(PackedVector2Array([tip, Vector2(at.x - s, base_y), Vector2(at.x + s, base_y)]), color)
	var tail_y := base_y - dir * s * 1.2
	view.draw_rect(Rect2(at.x - s * 0.25, minf(base_y, tail_y), s * 0.5, absf(tail_y - base_y)), color)


func _draw_overlay() -> void:
	if mode == null:
		return
	var card := top_rect().grow(-6.0)
	if _intro_left > 0.0:
		_overlay.draw_rect(card, Color(0.04, 0.09, 0.14, 0.92))
		_overlay.draw_rect(card, Color("ffd166"), false, 1.0)
		var font := ThemeDB.fallback_font
		FightMode.text(_overlay, Vector2(card.get_center().x, card.position.y + 10.0), str(_intro.get("title", "")), Color("ffd166"), 10)
		_overlay.draw_multiline_string(font, card.position + Vector2(6, 26), str(_intro.get("body", "")), HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 12.0, 7, -1, Color("eef6fa"))
		FightMode.text(_overlay, Vector2(card.get_center().x, card.end.y - 22.0), str(_intro.get("footer", "")), Color("9fc3d6"))
		var start := tr("Touch the bottom box to start") if not mode.uses_motion() else tr("Starting in %d...") % ceili(_intro_left)
		FightMode.text(_overlay, Vector2(card.get_center().x, card.end.y - 10.0), start, Color("f3e3b3"))
	elif _banner_left > 0.0:
		# First line large, any further lines (after "\n") smaller.
		var lines := _banner.split("\n")
		var height := 18.0 + 11.0 * (lines.size() - 1)
		var strip := Rect2(card.position.x, card.get_center().y - height / 2.0, card.size.x, height)
		_overlay.draw_rect(strip, Color(0.04, 0.09, 0.14, 0.85))
		FightMode.text(_overlay, Vector2(strip.get_center().x, strip.position.y + 9.0), lines[0], Color("ffd166"), 10)
		for i in range(1, lines.size()):
			FightMode.text(_overlay, Vector2(strip.get_center().x, strip.position.y + 9.0 + 11.0 * i), lines[i], Color("c9dbe4"), 7)
