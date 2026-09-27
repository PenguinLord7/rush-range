class_name UiTheme
## Shared colors and helpers for the arcade UI so every menu looks consistent.

const BG: Color = Color(0.05, 0.07, 0.12)
const BG_PANEL: Color = Color(0.10, 0.13, 0.21)
const CARD: Color = Color(0.13, 0.17, 0.26)
const ACCENT: Color = Color(0.18, 0.80, 0.74)
const ACCENT_WARM: Color = Color(1.0, 0.52, 0.16)
const TEXT: Color = Color(0.93, 0.96, 1.0)
const TEXT_DIM: Color = Color(0.62, 0.68, 0.80)
const DANGER: Color = Color(1.0, 0.35, 0.35)

static func apply_button(button: Button, color: Color = ACCENT) -> void:
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", BG)
	button.add_theme_stylebox_override("normal", _button_box(color.darkened(0.55), color, 8))
	button.add_theme_stylebox_override("hover", _button_box(color.darkened(0.3), color.lightened(0.1), 8))
	button.add_theme_stylebox_override("pressed", _button_box(color, color, 8))
	button.add_theme_stylebox_override("focus", _button_box(color.darkened(0.4), color, 8))
	button.custom_minimum_size = Vector2(260, 52)

static func _button_box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

static func title_label(text: String, size: int = 56) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

static func panel(bg: Color = BG_PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(14)
	box.set_border_width_all(2)
	box.border_color = ACCENT.darkened(0.4)
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 22
	box.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", box)
	return panel

## A row of [label | slider | value]. Returns { row, slider, value_label }.
static func labeled_slider(label_text: String, min_v: float, max_v: float,
		step: float, value: float, decimals: int = 2) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size.x = 190
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.add_theme_font_size_override("font_size", 18)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(280, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = ("%." + str(decimals) + "f") % value
	value_label.custom_minimum_size.x = 70
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", ACCENT)
	value_label.add_theme_font_size_override("font_size", 18)
	row.add_child(value_label)

	return {"row": row, "slider": slider, "value_label": value_label}

static func full_rect(node: Control) -> Control:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0
	return node

