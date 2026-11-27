class_name ResultsText
extends RefCounted
## The plain-text results testers copy and send back from the test screens.
## Stays in English on purpose (no tr()): it's a report for the developer.


static func header(screen: String, motion_sensor: bool) -> String:
	var screen_size := DisplayServer.screen_get_size()
	return "Sinoi the Fisherman %s, build %s, %s, screen %dx%d, motion sensor %s" % [screen,
		ProjectSettings.get_setting("application/config/version"), OS.get_name(),
		screen_size.x, screen_size.y, "yes" if motion_sensor else "no"]


## "caught | lost | avg catch s | accuracy %" for one session.
static func totals(s: FightSession) -> String:
	return "%d | %d | %s | %d" % [s.catches, s.escapes,
		("%.1f" % s.average_catch_time()) if s.catches > 0 else "-", roundi(s.accuracy() * 100.0)]


static func copy(lines: Array[String]) -> void:
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	print(text)
