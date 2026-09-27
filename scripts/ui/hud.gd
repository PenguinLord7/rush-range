extends Control
## Arcade HUD: score, weapon icon, ammo, reload state, notices, crosshair and
## hit markers. Listens to the Events bus so gameplay code stays decoupled.

const HIT_MARKER_TIME := 0.16

var _player: Player = null

var _kind: int = 0
var _ammo_current: int = 0
var _ammo_reserve: int = 0
var _reloading: bool = false
var _icon: Texture2D = null

var _score: int = 0
var _hit_timer: float = 0.0
var _hit_killed: bool = false
var _notice_timer: float = 0.0
var _dynamic: float = 0.0
var _move_spread: float = 0.0
var _ads: float = 0.0

var _score_label: Label
var _accuracy_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _reload_label: Label
var _icon_rect: TextureRect
var _notice_label: Label
var _capture_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Events.weapon_equipped.connect(_on_weapon)
	Events.ammo_changed.connect(_on_ammo)
	Events.reload_started.connect(_on_reload_started)
	Events.reload_finished.connect(_on_reload_finished)
	Events.score_changed.connect(_on_score)
	Events.hit_confirmed.connect(_on_hit)
	Events.notice.connect(_on_notice)
	Events.weapon_fired.connect(_on_fired)
	Events.target_destroyed.connect(_on_target_destroyed)
	_on_score(GameState.score)
	# The player's weapon manager emitted its first weapon before this HUD
	# connected, so ask it to announce the current weapon again.
	var holder = get_tree().get_first_node_in_group("player")
	if holder != null:
		holder = holder.get_weapon_holder()
	if holder != null:
		holder.switch_to(holder.current_index, true)

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	_notice_timer = maxf(_notice_timer - delta, 0.0)
	_dynamic = move_toward(_dynamic, 0.0, delta * 42.0)

	var speed := 0.0
	if _player != null:
		speed = Vector2(_player.velocity.x, _player.velocity.z).length()
	_move_spread = clampf(speed / 9.5, 0.0, 1.0) * 9.0

	_ads = 0.0
	if _player != null:
		var holder = _player.get_weapon_holder()
		if holder != null and holder.current_weapon() != null:
			_ads = holder.current_weapon().ads_amount()

	_notice_label.text = "" if _notice_timer <= 0.0 else _notice_label.text
	if _capture_label:
		_capture_label.visible = OS.has_feature("web") \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused
	queue_redraw()

# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	var center := size * 0.5
	var gap := (Settings.crosshair_gap + _dynamic + _move_spread)
	gap *= lerpf(1.0, 0.4, _ads)
	var length: float = Settings.crosshair_size
	var thickness: float = Settings.crosshair_thickness
	var color := Color(1, 1, 1, 0.92)
	# Four ticks.
	draw_rect(Rect2(center.x - thickness * 0.5, center.y - gap - length, thickness, length), color)
	draw_rect(Rect2(center.x - thickness * 0.5, center.y + gap, thickness, length), color)
	draw_rect(Rect2(center.x - gap - length, center.y - thickness * 0.5, length, thickness), color)
	draw_rect(Rect2(center.x + gap, center.y - thickness * 0.5, length, thickness), color)
	if Settings.crosshair_dot:
		draw_circle(center, thickness * 0.9, color)

	if _hit_timer > 0.0:
		var hc := Color(1.0, 0.32, 0.32) if _hit_killed else Color(1, 1, 1, 0.95)
		var d := 8.0
		var inner := 3.0
		draw_line(center + Vector2(-d, -d), center + Vector2(-inner, -inner), hc, 2.5)
		draw_line(center + Vector2(d, -d), center + Vector2(inner, -inner), hc, 2.5)
		draw_line(center + Vector2(-d, d), center + Vector2(-inner, inner), hc, 2.5)
		draw_line(center + Vector2(d, d), center + Vector2(inner, inner), hc, 2.5)

# --- UI construction -------------------------------------------------------

func _build() -> void:
	_score_label = UiTheme.title_label("SCORE 0", 30)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(_score_label, 24, 18, 400, 44)
	add_child(_score_label)

	_accuracy_label = UiTheme.title_label("ACCURACY 0%", 16)
	_accuracy_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_accuracy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(_accuracy_label, 26, 56, 400, 30)
	add_child(_accuracy_label)

	_notice_label = UiTheme.title_label("", 30)
	_notice_label.add_theme_color_override("font_color", UiTheme.ACCENT_WARM)
	_notice_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice_label.anchor_left = 0.5
	_notice_label.anchor_right = 0.5
	_notice_label.offset_left = -300
	_notice_label.offset_right = 300
	_notice_label.offset_top = 90
	_notice_label.offset_bottom = 130
	add_child(_notice_label)

	_capture_label = UiTheme.title_label("CLICK TO LOOK AROUND", 34)
	_capture_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	_capture_label.anchor_left = 0.5
	_capture_label.anchor_right = 0.5
	_capture_label.anchor_top = 0.5
	_capture_label.anchor_bottom = 0.5
	_capture_label.offset_left = -300
	_capture_label.offset_right = 300
	_capture_label.offset_top = -30
	_capture_label.offset_bottom = 30
	_capture_label.visible = false
	add_child(_capture_label)

	var panel := UiTheme.panel(Color(0.08, 0.11, 0.18, 0.86))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -296
	panel.offset_right = -18
	panel.offset_top = -116
	panel.offset_bottom = -18
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(92, 62)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.modulate = UiTheme.TEXT
	row.add_child(_icon_rect)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)

	_weapon_label = UiTheme.title_label("", 18)
	_weapon_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_weapon_label)

	_ammo_label = UiTheme.title_label("0", 40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_ammo_label)

	_reload_label = UiTheme.title_label("RELOADING", 18)
	_reload_label.add_theme_color_override("font_color", UiTheme.ACCENT_WARM)
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reload_label.visible = false
	col.add_child(_reload_label)

func _place(node: Control, left: float, top: float, width: float, height: float) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = left
	node.offset_top = top
	node.offset_right = left + width
	node.offset_bottom = top + height

# --- Event handlers --------------------------------------------------------

func _on_weapon(_slot: int, info: Dictionary) -> void:
	_kind = int(info.get("kind", 0))
	_weapon_label.text = str(info.get("name", ""))
	_icon = info.get("icon", null)
	if _icon_rect:
		_icon_rect.texture = _icon

func _on_ammo(current: int, reserve: int, reloading: bool) -> void:
	_ammo_current = current
	_ammo_reserve = reserve
	_reloading = reloading
	_reload_label.visible = reloading
	_update_ammo_text()

func _update_ammo_text() -> void:
	match _kind:
		1:
			_ammo_label.text = "∞"
		2:
			_ammo_label.text = str(_ammo_current)
		_:
			_ammo_label.text = "%d / %d" % [_ammo_current, maxi(_ammo_reserve, 0)]

func _on_reload_started(_duration: float) -> void:
	_reloading = true
	_reload_label.visible = true

func _on_reload_finished() -> void:
	_reloading = false
	_reload_label.visible = false

func _on_score(score: int) -> void:
	_score = score
	_score_label.text = "SCORE %d" % score

func _on_hit(killed: bool, _headshot: bool) -> void:
	_hit_timer = HIT_MARKER_TIME
	_hit_killed = killed
	if killed:
		_accuracy_label.text = "ACCURACY %d%%" % int(round(GameState.accuracy() * 100.0))

func _on_notice(text: String) -> void:
	_notice_label.text = text
	_notice_timer = 2.0 if text != "" else 0.0

func _on_fired() -> void:
	_dynamic = minf(_dynamic + 5.0, 28.0)
	_accuracy_label.text = "ACCURACY %d%%" % int(round(GameState.accuracy() * 100.0))

func _on_target_destroyed(_position: Vector3) -> void:
	_dynamic = minf(_dynamic + 8.0, 28.0)
