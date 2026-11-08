extends Control
## Title screen of the pre-production build.
##
## Everything here is placeholder: it exists to prove the pipeline (Godot ->
## web + Android), the touch input and the JSON save/load. Real art and the
## fishing fight replace it once production starts.

const AMAZON_URL := "https://www.amazon.com/dp/B0BT5XM4QC"
const WEST_MARCH_URL := "https://github.com/Deovandski/Vraki-West-March-Campaign-D-D"
const SUPPORT_TEXT := "Brought to you by Deovandski, author of the #HusbandOutWorld series and CEO/Founder of Wizard Deo Solutions. Have fun! If you want to support me, buy the eBooks on Amazon, or host a West March D&D campaign using the World Lore."

# Placeholder fish for the "Cast" button. Names follow the two-language rule
# (see docs/white-paper/02-design-direction.md); Sanbi is canon.
const PLACEHOLDER_FISH := [
	{"id": "magatum", "name": "Magatum", "pearls": Vector2i(3, 8)},
	{"id": "karkoi", "name": "Karkoi", "pearls": Vector2i(2, 5)},
	{"id": "bagnazu", "name": "Bagnazu", "pearls": Vector2i(2, 6)},
	{"id": "sanbi", "name": "Sanbi", "pearls": Vector2i(10, 25)},
]

var _stats: Label
var _status: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	theme = UiTheme.build()
	_build()
	SaveManager.changed.connect(_refresh)
	SaveManager.message.connect(_show_status)
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
	column.add_child(_label("Sinoi the Fisherman", 16, Color("f3e3b3")))
	column.add_child(_label("Pre-production build " + str(ProjectSettings.get_setting("application/config/version")), 7, Color("9fc3d6")))
	column.add_child(_label("Made for touch screens. A mouse works for testing.", 7, Color("c9dbe4")))
	column.add_child(_spacer(2))

	_stats = _label("", 9, Color("ffffff"))
	column.add_child(_stats)

	column.add_child(_button("Cast (placeholder)", _on_cast))
	column.add_child(_button("Touch test: fight box", _on_touch_test))
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


func _show_status(text: String) -> void:
	_status.text = text


func _on_cast() -> void:
	var fish: Dictionary = PLACEHOLDER_FISH[_rng.randi_range(0, PLACEHOLDER_FISH.size() - 1)]
	var range_: Vector2i = fish.pearls
	var pearls := _rng.randi_range(range_.x, range_.y)
	SaveManager.data.pearls = int(SaveManager.data.pearls) + pearls
	SaveManager.data.catches.append({
		"fish": fish.id,
		"pearls": pearls,
		"caught_at": Time.get_datetime_string_from_system(true),
	})
	SaveManager.save_local()
	_refresh()
	_show_status("Caught a %s! +%d pearls" % [fish.name, pearls])


func _on_touch_test() -> void:
	get_tree().change_scene_to_file("res://scenes/touch_test.tscn")


func _on_reset() -> void:
	SaveManager.reset()
	_show_status("Save reset.")
