class_name Balls
extends RefCounted
## Shows pearl amounts in the lore's ball currency (data/balls.json):
## 1 amethyst = 50 pearls, 1 aquamarine = 500, 1 sapphire = 5,000.

const PATH := "res://data/balls.json"

static var _balls: Array = []


static func denominations() -> Array:
	if _balls.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		_balls = parsed.balls if typeof(parsed) == TYPE_DICTIONARY and parsed.has("balls") else [{"name": "pearl", "pearls": 1}]
	return _balls


## "17.5 pearls", or "2 amethysts, 3.4 pearls" once it reaches a bigger ball.
static func format(pearls: float) -> String:
	var parts: Array[String] = []
	var left := maxf(pearls, 0.0)
	for ball in denominations():
		var worth := int(ball.pearls)
		if worth <= 1:
			break
		var count := floori(left / worth)
		if count > 0:
			parts.append("%d %s%s" % [count, ball.name, "" if count == 1 else "s"])
			left -= count * worth
	if left > 0.0001 or parts.is_empty():
		var whole := is_equal_approx(left, roundf(left))
		parts.append(("%d pearl%s" % [roundi(left), "" if roundi(left) == 1 else "s"]) if whole else "%.1f pearls" % left)
	return ", ".join(parts)
