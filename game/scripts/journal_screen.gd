extends Control
## Journal screen: every fish in the game, in fish.json order.
## Caught fish show how many, the best quality, the biggest catch, the
## average payoff (in balls), the first catch date, the region and a short
## lore teaser with a "Read more" link to the series' website (see CLAUDE.md,
## "Nudge the lore"). Fish not caught yet show "???" and where they're seen.

var _list: VBoxContainer
var _summary: Label


func _ready() -> void:
	theme = UiTheme.build()
	var bg := ColorRect.new()
	bg.color = Color("0d1b2a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 2
	top.offset_right = -2
	top.offset_top = 2
	top.offset_bottom = 15
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	top.add_child(UiParts.small_button("< Back", func(): get_tree().change_scene_to_file("res://scenes/main.tscn")))
	var title := Label.new()
	title.text = tr("Journal")
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("f3e3b3"))
	top.add_child(title)

	_summary = UiParts.small_label(Color("9fc3d6"))
	_summary.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_summary.offset_left = 4
	_summary.offset_top = 17
	_summary.offset_bottom = 27
	add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 29
	scroll.offset_left = 4
	scroll.offset_right = -4
	scroll.offset_bottom = -4
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)
	_fill()


func _fill() -> void:
	var journal: Dictionary = SaveManager.data.get("journal", {})
	var names: Array = FishCatalog.rewards().get("quality_names", ["Normal"])
	var species := 0
	var total := 0
	for fish in FishCatalog.entries():
		var e: Dictionary = journal.get(fish.id, {})
		var caught := int(e.get("caught", 0))
		if caught > 0:
			species += 1
			total += caught
		_list.add_child(_card(fish, e, names))
	_summary.text = tr("%d of %d fish found - %d caught in all") % [species, FishCatalog.entries().size(), total]


func _card(fish: Dictionary, e: Dictionary, names: Array) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("16324a")
	box.border_color = Color("3d6680")
	box.set_border_width_all(1)
	box.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	panel.add_child(column)
	var caught := int(e.get("caught", 0))
	var region := str(fish.get("region", ""))
	var name := Label.new()
	name.add_theme_font_size_override("font_size", 9)
	column.add_child(name)
	if caught == 0:
		name.text = "???"
		name.add_theme_color_override("font_color", Color("6fa3c0"))
		column.add_child(_line(tr("Seen around %s. Not caught yet.") % tr(region) if region != "" else tr("Not caught yet."), Color("6fa3c0")))
		return panel
	name.text = tr(str(fish.name))
	name.add_theme_color_override("font_color", Color("ffd166"))
	var quality := func(key: String) -> String: return tr(str(names[clampi(int(e.get(key, 0)), 0, names.size() - 1)]))
	column.add_child(_line(tr("Caught: %d   Best: %s") % [caught, quality.call("best_quality")]))
	column.add_child(_line(tr("Biggest: %.1f cm (%s)") % [float(e.get("biggest_cm", 0.0)), quality.call("biggest_quality")]))
	column.add_child(_line(tr("Average payoff: %s") % Balls.format(Journal.average_pearls(e))))
	column.add_child(_line(tr("First caught: %s") % str(e.get("first_caught_at", "")).left(10)))
	if region != "":
		column.add_child(_line(tr("Region: %s") % tr(region)))
	var lore := str(fish.get("lore", ""))
	if lore != "":
		column.add_child(_line(tr(lore), Color("c9dbe4"), true))
		var link := FishCatalog.lore_link()
		if link != "":
			var host := link.trim_prefix("https://").trim_prefix("http://").trim_suffix("/")
			var more := UiParts.small_button(tr("Read more on %s") % host, func(): OS.shell_open(link))
			more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			column.add_child(more)
	return panel


func _line(text: String, color := Color("eef6fa"), wrap := false) -> Label:
	var l := UiParts.small_label(color)
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(150, 0)
	return l
