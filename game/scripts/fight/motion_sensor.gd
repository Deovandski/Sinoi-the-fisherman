class_name MotionSensor
extends RefCounted
## Accelerometer reading for the Shake mode, in m/s^2 with gravity included.
##
## Android: Godot's Input.get_accelerometer(). Web: Godot doesn't read the
## browser's sensors, so this listens to the `devicemotion` event through
## JavaScriptBridge. Desktops (and phones without a sensor) never report
## anything, and `available()` stays false so the mode falls back to rubbing.

var _web: JavaScriptObject = null
var _seen := false


func _init() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			if (!window.sinoiMotion) {
				window.sinoiMotion = {x: 0, y: 0, z: 0};
				window.addEventListener('devicemotion', function (e) {
					var a = e.accelerationIncludingGravity || e.acceleration;
					if (!a || a.x === null) { return; }
					window.sinoiMotion.x = a.x;
					window.sinoiMotion.y = a.y;
					window.sinoiMotion.z = a.z;
				});
			}
		""", true)
		_web = JavaScriptBridge.get_interface("sinoiMotion")


func read() -> Vector3:
	var v := Vector3.ZERO
	if _web != null:
		v = Vector3(float(_web.x), float(_web.y), float(_web.z))
	else:
		v = Input.get_accelerometer()
	if v.length() > 0.1:
		_seen = true
	return v


func available() -> bool:
	return _seen
