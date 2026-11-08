class_name UiTheme
extends RefCounted
## Placeholder theme until the illustrator's UI kit (9-slice panels and
## buttons) arrives. Sizes are in base pixels (180 x 320 screen).


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 9

	var normal := _box(Color("23415a"), Color("6fa3c0"))
	var hover := _box(Color("2c5677"), Color("a9d3e8"))
	var pressed := _box(Color("173045"), Color("f3e3b3"))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color("f3e3b3")))
	theme.set_color("font_color", "Button", Color("eef6fa"))
	theme.set_color("font_pressed_color", "Button", Color("f3e3b3"))
	theme.set_font_size("font_size", "Button", 9)
	return theme


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box
