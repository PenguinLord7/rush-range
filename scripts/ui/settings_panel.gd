extends Control
## Reusable settings overlay used by the main menu and the pause menu.

var _rows: Array = []
var _checks: Array = []

func _ready() -> void:
	UiTheme.full_rect(self)
	visible = false
	_build()

func open() -> void:
	visible = true
	_refresh()

func close() -> void:
	visible = false

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	UiTheme.full_rect(dim)
	add_child(dim)

	var center := CenterContainer.new()
	UiTheme.full_rect(center)
	add_child(center)

	var panel := UiTheme.panel()
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	vbox.add_child(UiTheme.title_label("SETTINGS", 40))
	_add_slider(vbox, "Mouse Sensitivity", 0.0005, 0.006, 0.0001, "mouse_sensitivity", 4)
	_add_slider(vbox, "Field of View", 60.0, 110.0, 1.0, "fov", 0)
	_add_slider(vbox, "Master Volume", 0.0, 1.0, 0.01, "master_volume", 2)
	_add_slider(vbox, "Music Volume", 0.0, 1.0, 0.01, "music_volume", 2)
	_add_slider(vbox, "Effects Volume", 0.0, 1.0, 0.01, "effects_volume", 2)
	_add_slider(vbox, "Crosshair Size", 2.0, 20.0, 0.5, "crosshair_size", 1)
	_add_slider(vbox, "Crosshair Gap", 0.0, 24.0, 0.5, "crosshair_gap", 1)
	_add_slider(vbox, "Crosshair Thickness", 1.0, 6.0, 0.5, "crosshair_thickness", 1)

	var invert := CheckButton.new()
	invert.text = "Invert Vertical Look"
	invert.add_theme_font_size_override("font_size", 18)
	invert.toggled.connect(func(v: bool) -> void: Settings.set_value("invert_y", v))
	vbox.add_child(invert)
	_checks.append({"node": invert, "key": "invert_y"})

	var dot := CheckButton.new()
	dot.text = "Crosshair Dot"
	dot.add_theme_font_size_override("font_size", 18)
	dot.toggled.connect(func(v: bool) -> void: Settings.set_value("crosshair_dot", v))
	vbox.add_child(dot)
	_checks.append({"node": dot, "key": "crosshair_dot"})

	var shake := CheckButton.new()
	shake.text = "Screen Shake"
	shake.add_theme_font_size_override("font_size", 18)
	shake.toggled.connect(func(v: bool) -> void: Settings.set_value("screen_shake", v))
	vbox.add_child(shake)
	_checks.append({"node": shake, "key": "screen_shake"})

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var reset := Button.new()
	reset.text = "RESET"
	UiTheme.apply_button(reset, UiTheme.ACCENT_WARM)
	reset.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_refresh())
	row.add_child(reset)

	var back := Button.new()
	back.text = "BACK"
	UiTheme.apply_button(back)
	back.pressed.connect(close)
	row.add_child(back)

func _add_slider(parent: VBoxContainer, label: String, mn: float, mx: float,
		step: float, key: String, decimals: int) -> void:
	var data := UiTheme.labeled_slider(label, mn, mx, step, float(Settings.get(key)), decimals)
	parent.add_child(data["row"])
	var slider: HSlider = data["slider"]
	var value_label: Label = data["value_label"]
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v)
		value_label.text = ("%." + str(decimals) + "f") % v)
	_rows.append({"slider": slider, "value_label": value_label, "key": key, "decimals": decimals})

func _refresh() -> void:
	for row in _rows:
		var slider: HSlider = row["slider"]
		var value: float = float(Settings.get(row["key"]))
		slider.value = value
		row["value_label"].text = ("%." + str(row["decimals"]) + "f") % value
	for check in _checks:
		check["node"].button_pressed = bool(Settings.get(check["key"]))
