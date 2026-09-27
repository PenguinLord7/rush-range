extends Control
## Title screen. Original arcade styling; no third-party assets.

const GAME_SCENE := "res://scenes/main/game.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_panel.tscn"
const CONTROLS_SCENE := "res://scenes/ui/controls_panel.tscn"

var _settings: Control
var _controls: Control

func _ready() -> void:
	UiTheme.full_rect(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	if AudioManager.has_sound("menu_music"):
		AudioManager.play_music("menu_music", -10.0)

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	UiTheme.full_rect(bg)
	add_child(bg)

	# Decorative accent bars.
	var bar_top := ColorRect.new()
	bar_top.color = UiTheme.ACCENT
	bar_top.anchor_right = 1.0
	bar_top.offset_bottom = 8
	add_child(bar_top)
	var bar_bottom := ColorRect.new()
	bar_bottom.color = UiTheme.ACCENT_WARM
	bar_bottom.anchor_right = 1.0
	bar_bottom.anchor_top = 1.0
	bar_bottom.anchor_bottom = 1.0
	bar_bottom.offset_top = -8
	add_child(bar_bottom)

	var center := CenterContainer.new()
	UiTheme.full_rect(center)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	vbox.add_child(UiTheme.title_label("RUSH RANGE", 76))

	var subtitle := UiTheme.title_label("ARCADE SHOOTING RANGE", 22)
	subtitle.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	_add_button(vbox, "PLAY", UiTheme.ACCENT, func() -> void: get_tree().change_scene_to_file(GAME_SCENE))
	_add_button(vbox, "SETTINGS", UiTheme.ACCENT, func() -> void: _settings.open())
	_add_button(vbox, "CONTROLS", UiTheme.ACCENT, func() -> void: _controls.open())
	_add_button(vbox, "QUIT", UiTheme.DANGER, func() -> void: get_tree().quit())

	var hint := UiTheme.title_label("WASD move  ·  SHIFT sprint  ·  CTRL crouch  ·  LMB fire", 16)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	vbox.add_child(hint)

	_settings = (load(SETTINGS_SCENE) as PackedScene).instantiate()
	add_child(_settings)
	_controls = (load(CONTROLS_SCENE) as PackedScene).instantiate()
	add_child(_controls)

func _add_button(parent: VBoxContainer, text: String, color: Color, action: Callable) -> Button:
	var holder := CenterContainer.new()
	parent.add_child(holder)
	var button := Button.new()
	button.text = text
	UiTheme.apply_button(button, color)
	button.pressed.connect(action)
	button.mouse_entered.connect(func() -> void: AudioManager.play_sfx("hover", -18.0))
	button.pressed.connect(func() -> void: AudioManager.play_sfx("click", -10.0))
	holder.add_child(button)
	return button
