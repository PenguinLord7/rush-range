extends Control
## Reusable controls reference overlay.

const CONTROLS: Array = [
	["W A S D", "Move"],
	["SPACE", "Jump"],
	["SHIFT", "Sprint"],
	["C", "Crouch"],
	["C while sprinting", "Slide"],
	["LEFT MOUSE", "Fire / Punch / Throw"],
	["RIGHT MOUSE", "Aim down sights"],
	["R", "Reload"],
	["1 - 4", "Switch weapon"],
	["MOUSE WHEEL", "Cycle weapon"],
	["ESC", "Menu / pause"],
]

func _ready() -> void:
	UiTheme.full_rect(self)
	visible = false
	_build()

func open() -> void:
	visible = true

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
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	vbox.add_child(UiTheme.title_label("CONTROLS", 40))

	for entry in CONTROLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var key := Label.new()
		key.text = entry[0]
		key.custom_minimum_size.x = 250
		key.add_theme_font_size_override("font_size", 20)
		key.add_theme_color_override("font_color", UiTheme.ACCENT)
		row.add_child(key)
		var action := Label.new()
		action.text = entry[1]
		action.add_theme_font_size_override("font_size", 20)
		action.add_theme_color_override("font_color", UiTheme.TEXT)
		row.add_child(action)
		vbox.add_child(row)

	var back := Button.new()
	back.text = "BACK"
	UiTheme.apply_button(back)
	back.pressed.connect(close)
	var holder := CenterContainer.new()
	holder.add_child(back)
	vbox.add_child(holder)
