class_name FightMode
extends RefCounted
## One fight-box mode. The host (scripts/touch_test.gd) owns the two pads,
## the catch meter and the stats; a mode only judges input and draws.
##
## Coordinates are pad space: (0, 0) is the pad's top-left corner and both
## axes run to `side`. The host converts touches into pad space (from
## whichever box is the playing one), so modes never see screen positions.
##
## Meter changes are fractions of the catch meter: it starts at 0.25, the
## fish is caught at 1.0 and gets away at 0. Tuning numbers come from
## data/fight_modes.json so they can be balanced without touching code.
##
## Every mode can be easy or hard. `difficulty` runs from 0 (easiest) to 1
## (hardest); a tuning value written as [easy, hard] is blended by it, so
## each fish can later pick its own difficulty per mode.

## Which box is live. Only the Lost Ref mode changes it.
## NORMAL: play in the bottom box, read the top one. WARN_UP: both boxes
## pulse, the bottom is about to go out. TOP_ONLY: the bottom box is out
## (red, arrow up); play in the top box, the only one left. BACK_DOWN: for a
## second the top box flashes yellow and the bottom (still red, arrow down)
## is live again; then the top box returns as the reference.
enum Pads { NORMAL, WARN_UP, TOP_ONLY, BACK_DOWN }

const GOLD := Color("ffd166")
const GREEN := Color("06d6a0")
const RED := Color("ef476f")
const BLUE := Color("118ab2")
const WHITE := Color("eef6fa")
const FAINT := Color(1, 0.82, 0.4, 0.45)
const POP_TIME := 0.6

var id := ""
var tuning := {}
var side := 120.0
## 0 = easiest, 1 = hardest (the touch test's slider shows 0-10). Tuning
## is read live, so a fish section can raise it while the fight goes on.
var difficulty := 0.5:
	set(value):
		difficulty = clampf(value, 0.0, 1.0)
		_difficulty_changed()
var time := 0.0
## Short live instruction shown under the meter ("Faster!", "Lift!").
var cue := ""
## Sound names the host should play this frame ("tick", "tock", "hit", "miss").
var sounds: Array[String] = []
var rng := RandomNumberGenerator.new()

var _good := 0.0
var _judged := 0.0
var _pops: Array = []  # [position, text, color, time left]


func setup(p_id: String, p_tuning: Dictionary, p_side: float, p_difficulty := 0.5) -> void:
	id = p_id
	tuning = p_tuning
	side = p_side
	difficulty = p_difficulty
	if tuning.has("seed"):
		rng.seed = int(tuning.seed)
	else:
		rng.randomize()
	_start()


# --- What a mode overrides --------------------------------------------------

## Most fingers this mode reads (the host ignores the rest).
func max_fingers() -> int:
	return 1


## True if the mode reads the motion sensor (the host then calls motion()).
func uses_motion() -> bool:
	return false


## Which box is live right now (see Pads).
func pads() -> Pads:
	return Pads.NORMAL


func _start() -> void:
	pass


## Called whenever `difficulty` changes (Lost Ref passes it to its inner mode).
func _difficulty_changed() -> void:
	pass


## Per frame. `fingers` maps touch index -> pad position. Returns the meter change.
func _step(_delta: float, _fingers: Dictionary) -> float:
	return 0.0


## A finger went down or up inside the pad. Returns an instant meter change.
func touch(_index: int, _position: Vector2, _pressed: bool) -> float:
	return 0.0


## Motion sensor reading in m/s^2 (gravity included); `available` is false
## while no sensor has reported anything.
func motion(_acceleration: Vector3, _available: bool) -> void:
	pass


## Draw the shadow pad (full picture) or the real pad (light outlines only,
## because fingers cover it).
func _draw_pad(_canvas: CanvasItem, _shadow: bool) -> void:
	pass


# --- Shared plumbing ----------------------------------------------------------

func step(delta: float, fingers: Dictionary) -> float:
	time += delta
	for p in _pops:
		p[3] -= delta
	_pops = _pops.filter(func(p): return p[3] > 0.0)
	return _step(delta, fingers)


func draw_pad(canvas: CanvasItem, shadow: bool) -> void:
	_draw_pad(canvas, shadow)
	if shadow:
		for p in _pops:
			var rise: float = (POP_TIME - p[3]) * 10.0
			text(canvas, p[0] - Vector2(0, 8 + rise), p[1], Color(p[2], clampf(p[3] / POP_TIME * 2.0, 0.0, 1.0)))


## Hands the judgement totals since the last call to the host and resets them.
func take_judgement() -> Vector2:
	var out := Vector2(_good, _judged)
	_good = 0.0
	_judged = 0.0
	return out


## Records one judgement: `score` 0..1, `weight` is 1 for an event or delta
## seconds for continuous checks.
func judge(score: float, weight := 1.0) -> void:
	_judged += weight
	_good += clampf(score, 0.0, 1.0) * weight


func pop(at: Vector2, label: String, color: Color) -> void:
	_pops.append([at, label, color, POP_TIME])


func sfx(sound: String) -> void:
	sounds.append(sound)


## A tuning number at the current difficulty: plain numbers as they are,
## [easy, hard] pairs blended by `difficulty`.
func num(key: String, fallback: float) -> float:
	var value: Variant = tuning.get(key, fallback)
	if value is Array and value.size() == 2:
		return lerpf(float(value[0]), float(value[1]), difficulty)
	return float(value)


func center() -> Vector2:
	return Vector2(side, side) / 2.0


func clamp_in_pad(p: Vector2, margin: float) -> Vector2:
	return Vector2(clampf(p.x, margin, side - margin), clampf(p.y, margin, side - margin))


static func text(canvas: CanvasItem, at: Vector2, label: String, color: Color, size := 7) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, Vector2(roundf(at.x - width / 2.0), roundf(at.y + size / 2.0 - 1.0)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func ring(canvas: CanvasItem, at: Vector2, radius: float, color: Color, width := 1.0) -> void:
	canvas.draw_arc(at, radius, 0.0, TAU, maxi(16, int(radius * 2.0)), color, width)


## Arc that fills clockwise from 12 o'clock, for hold and timer rings.
static func progress_arc(canvas: CanvasItem, at: Vector2, radius: float, amount: float, color: Color, width := 2.0) -> void:
	if amount <= 0.0:
		return
	canvas.draw_arc(at, radius, -PI / 2.0, -PI / 2.0 + TAU * clampf(amount, 0.0, 1.0), maxi(8, int(radius * 2.0)), color, width)
