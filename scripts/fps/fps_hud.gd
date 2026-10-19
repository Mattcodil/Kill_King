## fps_hud.gd
## In-duel HUD, built entirely in code: crosshair, hit marker, both health
## bars, ammo, countdown timer, big result banner and a damage flash.

class_name FpsHud
extends CanvasLayer

const PLAYER_BAR_W := 300.0
const ENEMY_BAR_W := 380.0

var _title: Label
var _timer: Label
var _banner: Label
var _sub_banner: Label
var _weapon_label: Label
var _ammo_label: Label
var _hp_fill: ColorRect
var _hp_label: Label
var _enemy_fill: ColorRect
var _enemy_label: Label
var _flash: ColorRect
var _hit_marker: Control
var _hit_tween: Tween = null
var _debug_label: Label

func _init() -> void:
	layer = 50

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Damage flash (under everything else).
	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	# Title (top centre) and timer (top right).
	_title = _make_label("", 26, Color(1, 0.92, 0.7))
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.anchor_left = 0.0
	_title.anchor_right = 1.0
	_title.offset_left = 0
	_title.offset_right = 0
	_title.offset_top = 10
	_title.offset_bottom = 44
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)

	_timer = _make_label("", 28, Color.WHITE)
	_timer.anchor_left = 1.0
	_timer.anchor_right = 1.0
	_timer.offset_left = -140
	_timer.offset_right = -20
	_timer.offset_top = 10
	_timer.offset_bottom = 48
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_timer)

	# Enemy health bar (top centre, under the title).
	_enemy_label = _make_label("", 18, Color(1, 0.7, 0.7))
	_enemy_label.anchor_left = 0.5
	_enemy_label.anchor_right = 0.5
	_enemy_label.offset_left = -ENEMY_BAR_W * 0.5
	_enemy_label.offset_right = ENEMY_BAR_W * 0.5
	_enemy_label.offset_top = 48
	_enemy_label.offset_bottom = 72
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_enemy_label)
	var enemy_bg := _make_bar(root, 0.5, 0.0, -ENEMY_BAR_W * 0.5, 74.0, ENEMY_BAR_W, 14.0)
	_enemy_fill = enemy_bg.get_child(0) as ColorRect
	_enemy_fill.color = Color(0.85, 0.15, 0.15)

	# Player health (bottom left).
	_hp_label = _make_label("", 20, Color.WHITE)
	_hp_label.anchor_top = 1.0
	_hp_label.anchor_bottom = 1.0
	_hp_label.offset_left = 24
	_hp_label.offset_right = 24 + PLAYER_BAR_W
	_hp_label.offset_top = -78
	_hp_label.offset_bottom = -52
	root.add_child(_hp_label)
	var hp_bg := _make_bar(root, 0.0, 1.0, 24.0, -48.0, PLAYER_BAR_W, 20.0)
	_hp_fill = hp_bg.get_child(0) as ColorRect
	_hp_fill.color = Color(0.2, 0.8, 0.3)

	# Weapon + ammo (bottom right).
	_weapon_label = _make_label("", 20, Color(1, 0.92, 0.7))
	_weapon_label.anchor_left = 1.0
	_weapon_label.anchor_right = 1.0
	_weapon_label.anchor_top = 1.0
	_weapon_label.anchor_bottom = 1.0
	_weapon_label.offset_left = -340
	_weapon_label.offset_right = -24
	_weapon_label.offset_top = -100
	_weapon_label.offset_bottom = -72
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_weapon_label)
	_ammo_label = _make_label("", 42, Color.WHITE)
	_ammo_label.anchor_left = 1.0
	_ammo_label.anchor_right = 1.0
	_ammo_label.anchor_top = 1.0
	_ammo_label.anchor_bottom = 1.0
	_ammo_label.offset_left = -340
	_ammo_label.offset_right = -24
	_ammo_label.offset_top = -72
	_ammo_label.offset_bottom = -16
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_ammo_label)

	# Crosshair + hit marker (screen centre).
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	for r: Rect2 in [Rect2(-15, -1, 10, 2), Rect2(5, -1, 10, 2), Rect2(-1, -15, 2, 10), Rect2(-1, 5, 2, 10)]:
		var cr := ColorRect.new()
		cr.color = Color(1, 1, 1, 0.9)
		cr.position = r.position
		cr.size = r.size
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(cr)
	_hit_marker = Control.new()
	_hit_marker.modulate.a = 0.0
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_hit_marker)
	for ang: float in [PI * 0.25, -PI * 0.25]:
		var line := ColorRect.new()
		line.color = Color.WHITE
		line.size = Vector2(22, 3)
		line.position = Vector2(-11, -1.5)
		line.pivot_offset = Vector2(11, 1.5)
		line.rotation = ang
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hit_marker.add_child(line)

	# Debug line (F3), bottom centre, hidden unless text is set.
	_debug_label = _make_label("", 14, Color(0.7, 1.0, 0.7))
	_debug_label.anchor_left = 0.0
	_debug_label.anchor_right = 1.0
	_debug_label.anchor_top = 1.0
	_debug_label.anchor_bottom = 1.0
	_debug_label.offset_top = -130
	_debug_label.offset_bottom = -105
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_debug_label)

	# Big banner (countdown / result).
	_banner = _make_label("", 72, Color.WHITE)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.28
	_banner.anchor_bottom = 0.28
	_banner.offset_top = -50
	_banner.offset_bottom = 50
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_banner)
	_sub_banner = _make_label("", 26, Color(0.9, 0.9, 0.9))
	_sub_banner.anchor_left = 0.0
	_sub_banner.anchor_right = 1.0
	_sub_banner.anchor_top = 0.28
	_sub_banner.anchor_bottom = 0.28
	_sub_banner.offset_top = 52
	_sub_banner.offset_bottom = 90
	_sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_sub_banner)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l

## Background rect with one child ColorRect used as the fill.
func _make_bar(parent: Control, anchor_x: float, anchor_y: float,
		off_x: float, off_y: float, w: float, h: float) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.anchor_left = anchor_x
	bg.anchor_right = anchor_x
	bg.anchor_top = anchor_y
	bg.anchor_bottom = anchor_y
	bg.offset_left = off_x
	bg.offset_right = off_x + w
	bg.offset_top = off_y
	bg.offset_bottom = off_y + h
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.position = Vector2(2, 2)
	fill.size = Vector2(w - 4, h - 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	return bg

# ── Public API ─────────────────────────────────────────────────────────────
func set_title(text: String) -> void:
	_title.text = text

func set_timer(seconds_left: float) -> void:
	var s := maxi(int(ceil(seconds_left)), 0)
	_timer.text = "%d:%02d" % [s / 60, s % 60]

func set_player_hp(cur: float, max_hp: float) -> void:
	var ratio := clampf(cur / maxf(max_hp, 1.0), 0.0, 1.0)
	_hp_fill.size.x = (PLAYER_BAR_W - 4.0) * ratio
	_hp_fill.color = Color(0.2, 0.8, 0.3).lerp(Color(0.9, 0.15, 0.1), 1.0 - ratio)
	_hp_label.text = "HP  %d / %d" % [ceili(cur), int(max_hp)]

func set_enemy(enemy_name: String, cur: float, max_hp: float) -> void:
	var ratio := clampf(cur / maxf(max_hp, 1.0), 0.0, 1.0)
	_enemy_fill.size.x = (ENEMY_BAR_W - 4.0) * ratio
	_enemy_label.text = "%s  %d / %d" % [enemy_name, ceili(cur), int(max_hp)]

func set_weapon(weapon_name: String) -> void:
	_weapon_label.text = weapon_name

func set_ammo(cur: int, mag: int, reloading: bool) -> void:
	if reloading:
		_ammo_label.text = "RELOADING"
		_ammo_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	else:
		_ammo_label.text = "%d / %d" % [cur, mag]
		var low := cur <= maxi(int(mag * 0.25), 1)
		_ammo_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if low else Color.WHITE)

func set_debug(text: String) -> void:
	_debug_label.text = text

func show_banner(text: String, sub: String = "", color: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_sub_banner.text = sub

func clear_banner() -> void:
	_banner.text = ""
	_sub_banner.text = ""

func flash_damage() -> void:
	_flash.color.a = 0.35
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)

func hit_marker(killed: bool) -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	var col := Color(1, 0.2, 0.2) if killed else Color.WHITE
	for c in _hit_marker.get_children():
		(c as ColorRect).color = col
	_hit_marker.modulate.a = 1.0
	_hit_tween = create_tween()
	_hit_tween.tween_property(_hit_marker, "modulate:a", 0.0, 0.22)
