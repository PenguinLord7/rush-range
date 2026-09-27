class_name InputState
## Whether gameplay input (look/move/fire) should be accepted.
##
## On the web the mouse must be pointer-locked (click the page once) before
## controls work. On desktop the mouse is always captured during play, and the
## headless test harnesses are not the "web" feature, so they stay active.

static func gameplay_active() -> bool:
	return not OS.has_feature("web") or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
