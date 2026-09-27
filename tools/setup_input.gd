extends SceneTree
## One-shot editor tool: registers the game's input actions on the project and
## saves project.godot. Run with:
##
##   godot --headless --path . --script res://tools/setup_input.gd
##
## Re-run after deleting the [input] section of project.godot.
##
## Physical keycodes are used so the layout is the same on any keyboard.

func _initialize() -> void:
	var actions := {
		"move_forward": [_key(KEY_W)],
		"move_back": [_key(KEY_S)],
		"move_left": [_key(KEY_A)],
		"move_right": [_key(KEY_D)],
		"jump": [_key(KEY_SPACE)],
		"sprint": [_key(KEY_SHIFT)],
		"crouch": [_key(KEY_CTRL)],
		"fire": [_mouse(MOUSE_BUTTON_LEFT)],
		"aim": [_mouse(MOUSE_BUTTON_RIGHT)],
		"reload": [_key(KEY_R)],
		"weapon_1": [_key(KEY_1)],
		"weapon_2": [_key(KEY_2)],
		"weapon_3": [_key(KEY_3)],
		"weapon_4": [_key(KEY_4)],
		"weapon_next": [_mouse(MOUSE_BUTTON_WHEEL_UP)],
		"weapon_prev": [_mouse(MOUSE_BUTTON_WHEEL_DOWN)],
		"pause": [_key(KEY_ESCAPE)],
		"restart": [_key(KEY_F5)],
	}

	for action in actions:
		ProjectSettings.set_setting("input/" + action, {
			"deadzone": 0.2,
			"events": actions[action],
		})

	var err := ProjectSettings.save()
	if err != OK:
		push_error("setup_input: failed to save project settings (%d)" % err)
	else:
		print("setup_input: registered %d actions." % actions.size())
	quit()

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
