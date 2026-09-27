extends Control
## In-game pause overlay (ESC). Emits intents the game scene handles.

signal resume_pressed
signal restart_pressed
signal menu_pressed

const SETTINGS_SCENE := "res://scenes/ui/settings_panel.tscn"
const CONTROLS_SCENE := "res://scenes/ui/controls_panel.tscn"

var _settings: Control
var _controls: Control

func _ready() -> void:
	UiTheme.full_rect(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func open() -> void:
	visible = true

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Runs while the tree is paused (PROCESS_MODE_ALWAYS), so ESC closes it.
	if visible and event.is_action_pressed("pause"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	UiTheme.full_rect(dim)
	add_child(dim)

	var center := CenterContainer.new()
	UiTheme.full_rect(center)
	add_child(center)

	var panel := UiTheme.panel()
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	vbox.add_child(UiTheme.title_label("PAUSED", 52))
	_add_button(vbox, "RESUME", UiTheme.ACCENT, func() -> void: resume_pressed.emit())
	_add_button(vbox, "SETTINGS", UiTheme.ACCENT, func() -> void: _settings.open())
	_add_button(vbox, "CONTROLS", UiTheme.ACCENT, func() -> void: _controls.open())
	_add_button(vbox, "RESTART", UiTheme.ACCENT_WARM, func() -> void: restart_pressed.emit())
	_add_button(vbox, "MAIN MENU", UiTheme.DANGER, func() -> void: menu_pressed.emit())

	_settings = (load(SETTINGS_SCENE) as PackedScene).instantiate()
	add_child(_settings)
	_controls = (load(CONTROLS_SCENE) as PackedScene).instantiate()
	add_child(_controls)

func _add_button(parent: VBoxContainer, text: String, color: Color, action: Callable) -> void:
	var holder := CenterContainer.new()
	parent.add_child(holder)
	var button := Button.new()
	button.text = text
	UiTheme.apply_button(button, color)
	button.pressed.connect(action)
	button.mouse_entered.connect(func() -> void: AudioManager.play_sfx("hover", -18.0))
	holder.add_child(button)
