extends Control
## Title screen of the pre-production build.
##
## Everything here is placeholder: it exists to prove the pipeline (Godot ->
## web + Android), the touch input and the JSON save/load. Real art and the
## fishing fight replace it once production starts.

const AMAZON_URL := "https://www.amazon.com/dp/B0BT5XM4QC"
const WEST_MARCH_URL := "https://github.com/Deovandski/Vraki-West-March-Campaign-D-D"
const SUPPORT_TEXT := "Brought to you by Deovandski, author of the #HusbandOutWorld series and CEO/Founder of Wizard Deo Solutions. Have fun! If you want to support me, buy the eBooks on Amazon, or host a West March D&D campaign using the World Lore."


var _stats: Label
var _status: Label
var _update_button: Button


func _ready() -> void:
	theme = UiTheme.build()
	_build()
	SaveManager.changed.connect(_refresh)
	SaveManager.message.connect(_show_status)
	_watch_for_web_update()
	_refresh()


func _build() -> void:
	var sky := ColorRect.new()
	sky.color = Color("10243a")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	var water := ColorRect.new()
	water.color = Color("16486a")
	water.anchor_left = 0.0
	water.anchor_right = 1.0
	water.anchor_top = 0.62
	water.anchor_bottom = 1.0
	add_child(water)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(164, 0)
	column.add_theme_constant_override("separation", 3)
	center.add_child(column)

	column.add_child(_spacer(8))
	# Shown only when the installed web app (PWA) has downloaded a new version.
	_update_button = _button("New version ready: tap to update", _on_update_pressed)
	_update_button.visible = false
	column.add_child(_update_button)
	column.add_child(_label("Sinoi the Fisherman", 16, Color("f3e3b3")))
	column.add_child(_label("Pre-production build " + str(ProjectSettings.get_setting("application/config/version")), 7, Color("9fc3d6")))
	column.add_child(_label("Made for touch screens. A mouse works for testing.", 7, Color("c9dbe4")))
	column.add_child(_spacer(2))

	_stats = _label("", 9, Color("ffffff"))
	column.add_child(_stats)

	column.add_child(_button("Fish test: fight a fish", _on_fish_test))
	column.add_child(_button("Fight box: try the modes", _on_touch_test))
	column.add_child(_row([
		_button("Export save", SaveManager.export_save),
		_button("Import save", SaveManager.import_save),
	]))
	var tools: Array[Control] = [_button("Reset save", _on_reset)]
	if not OS.has_feature("web"):
		tools.push_front(_button("Paste save", SaveManager.import_from_clipboard))
	column.add_child(_row(tools))

	_status = _label("", 7, Color("ffe08a"))
	column.add_child(_status)

	column.add_child(_spacer(4))
	column.add_child(_label(SUPPORT_TEXT, 6, Color("d7e6ec")))
	column.add_child(_row([
		_button("eBooks on Amazon", func(): OS.shell_open(AMAZON_URL)),
		_button("World Lore", func(): OS.shell_open(WEST_MARCH_URL)),
	]))
	column.add_child(_spacer(8))


func _row(children: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for child in children:
		child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(child)
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(164, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_press)
	return button


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _refresh() -> void:
	var catches: Array = SaveManager.data.get("catches", [])
	_stats.text = "Pearls: %d   Catches: %d" % [int(SaveManager.data.get("pearls", 0)), catches.size()]


## Web/PWA only: the service worker downloads a new build in the background
## and waits. Offer a button instead of reloading under the player.
func _watch_for_web_update() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.pwa_update_available.connect(_show_update_button)
	if JavaScriptBridge.pwa_needs_update():
		_show_update_button()
	# Browsers don't reliably re-check the service worker when an installed
	# app opens, so check after launch (at 5 s and 30 s), whenever the app
	# comes back to the foreground, and every 10 minutes while it's open.
	# Offline, the check fails quietly.
	JavaScriptBridge.eval("""
		if ('serviceWorker' in navigator && !window.sinoiUpdateTimer) {
			var sinoiCheckForUpdate = function () {
				navigator.serviceWorker.getRegistration()
					.then(function (r) { return r ? r.update() : null; })
					.catch(function () {});
			};
			setTimeout(sinoiCheckForUpdate, 5000);
			setTimeout(sinoiCheckForUpdate, 30000);
			window.sinoiUpdateTimer = setInterval(sinoiCheckForUpdate, 600000);
			document.addEventListener('visibilitychange', function () {
				if (document.visibilityState === 'visible') { sinoiCheckForUpdate(); }
			});
		}
	""", true)


func _show_update_button() -> void:
	_update_button.visible = true


func _on_update_pressed() -> void:
	SaveManager.save_local()
	JavaScriptBridge.pwa_update()


func _show_status(text: String) -> void:
	_status.text = text


func _on_fish_test() -> void:
	get_tree().change_scene_to_file("res://scenes/fish_test.tscn")


func _on_touch_test() -> void:
	get_tree().change_scene_to_file("res://scenes/touch_test.tscn")


func _on_reset() -> void:
	SaveManager.reset()
	_show_status("Save reset.")
