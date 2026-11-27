class_name UiParts
extends RefCounted
## Small placeholder UI pieces shared by the test screens.


static func small_button(label: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.add_theme_font_size_override("font_size", 7)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


## A drop-down listing `names`; `on_pick` gets the chosen index.
static func picker(names: PackedStringArray, on_pick: Callable) -> OptionButton:
	var p := OptionButton.new()
	p.focus_mode = Control.FOCUS_NONE
	p.fit_to_longest_item = false
	p.clip_text = true
	for n in names:
		p.add_item(n)
	p.item_selected.connect(on_pick)
	return p


static func small_label(color := Color("c9dbe4")) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", color)
	return l


## The row under the picker: Back, a stats label (returned) and Copy.
static func status_row(parent: Control, y: float, on_copy: Callable) -> Label:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 2
	row.offset_right = -2
	row.offset_top = y
	row.offset_bottom = y + 13
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	row.add_child(small_button(TranslationServer.translate("< Back"), func(): parent.get_tree().change_scene_to_file("res://scenes/main.tscn")))
	var stats := small_label()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.clip_text = true
	row.add_child(stats)
	row.add_child(small_button(TranslationServer.translate("Copy"), on_copy))
	return stats
