## fps_player.gd
## First-person controller used during a capture duel.
## WASD move, Shift sprint, Space jump, mouse look, LMB fire, R reload.
## Hitscan shooting (raycast from the screen centre).

class_name FpsPlayer
extends CharacterBody3D

signal hp_changed(cur: float, max_hp: float)
signal ammo_changed(cur: int, mag: int, reloading: bool)
signal damaged
signal hit_enemy(killed: bool)
signal died

const GRAVITY := 22.0
const JUMP_SPEED := 6.5
const SPRINT_MULT := 1.5
const EYE_HEIGHT := 1.6
const MAX_RANGE := 150.0
const MOUSE_SENS := 0.0022
const TURN_RATE := 2.4           # rad/s for keyboard / stick turning (player 2)
const BODY_PIECE_SCALE := 0.10   # same as the AI opponent's model
const GUN_FORWARD := 0.95
const GUN_RIGHT := 0.30
const GUN_SCALE := 1.8

var def: Dictionary = {}
var hp: float = 100.0
var max_hp: float = 100.0
var ammo: int = 0
var enabled: bool = false     # input + shooting allowed
var dead: bool = false
var camera: Camera3D = null

var _reloading: bool = false
var _reload_left: float = 0.0
var _cooldown: float = 0.0
var _trigger_was_down: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _kick: float = 0.0          # visual recoil, decays
var _bob_t: float = 0.0
var _view: Node3D = null        # viewmodel root (child of camera)
var _muzzle: Node3D = null
var _flash_light: OmniLight3D = null
var _flash_timer: float = 0.0
var _fx_parent: Node = null     # where tracers/impacts are parented (the arena)

# ── Two-human split-screen mode (slot 0 = mouse+keyboard, slot 1 = arrows / gamepad) ──
var slot: int = -1              # -1 = classic single player vs AI
var _ext_cam: bool = false      # camera lives in a SubViewport and is positioned by hand
var _cam_drop: float = 0.0
var _cam_roll: float = 0.0
var _body_piece: BasePiece = null
var _body_pivot: Node3D = null
var _tag: Label3D = null
var _tag_base: String = ""
var _body_walking: bool = false
var _reload_key_was_down: bool = false
var _gp_device: int = 0

func setup(weapon_def: Dictionary, fx_parent: Node) -> void:
	def = weapon_def
	_fx_parent = fx_parent
	max_hp = float(def["hp"])
	hp = max_hp
	ammo = int(def["mag"])

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var u := FpsFx.unit
	cap.radius = 0.4 * u
	cap.height = 1.8 * u
	col.shape = cap
	col.position = Vector3(0, 0.9 * u, 0)
	add_child(col)

	camera = Camera3D.new()
	camera.position = Vector3(0, EYE_HEIGHT * u, 0)
	camera.fov = 78.0
	camera.near = 0.03 * u
	camera.far = 300.0
	add_child(camera)

	_view = Node3D.new()
	camera.add_child(_view)
	var gun := FpsWeaponModels.build(String(def["kind"]))
	_view.add_child(gun)
	_view.position = Vector3(0.20, -0.20, -0.42) * u
	_view.scale = Vector3.ONE * u
	_muzzle = gun.get_node_or_null("Muzzle") as Node3D
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.7, 0.3)
	_flash_light.omni_range = 6.0 * u
	_flash_light.light_energy = 0.0
	if _muzzle != null:
		_muzzle.add_child(_flash_light)
	else:
		_view.add_child(_flash_light)

	hp_changed.emit(hp, max_hp)
	ammo_changed.emit(ammo, int(def["mag"]), false)

## Body layer (seen by the other player only) and viewmodel layer (seen by the owner only).
static func body_layer(slot_i: int) -> int:
	return 1 << (1 + slot_i)

static func view_layer(slot_i: int) -> int:
	return 1 << (3 + slot_i)

## Split-screen set-up: moves the camera into this player's SubViewport, builds a
## visible body (the real piece model + floating gun) for the opponent to see.
func setup_pvp(slot_i: int, sub: SubViewport, piece_scene: PackedScene, piece_type: int,
		piece_color: int, label: String) -> void:
	slot = slot_i
	_ext_cam = true
	var cam_pos := camera.global_position
	remove_child(camera)
	sub.add_child(camera)
	camera.global_position = cam_pos
	camera.cull_mask = 0xFFFFF & ~body_layer(slot) & ~view_layer(1 - slot)
	_set_layers(_view, view_layer(slot))

	if piece_scene != null:
		_body_piece = piece_scene.instantiate() as BasePiece
	if _body_piece != null:
		_body_piece.piece_type = piece_type
		_body_piece.piece_color = piece_color
		_body_piece.use_weapon = false
		_body_piece.scale = Vector3.ONE * BODY_PIECE_SCALE * FpsFx.unit
		add_child(_body_piece)
		_body_piece.position = Vector3.ZERO
	_body_pivot = Node3D.new()
	_body_pivot.position = Vector3(0, 1.15, 0) * FpsFx.unit
	add_child(_body_pivot)
	var body_gun := FpsWeaponModels.build(String(def["kind"]))
	body_gun.position = Vector3(GUN_RIGHT, 0.0, -GUN_FORWARD) * FpsFx.unit
	body_gun.scale = Vector3.ONE * GUN_SCALE * FpsFx.unit
	_body_pivot.add_child(body_gun)
	_tag = Label3D.new()
	_tag_base = label
	_tag.text = "%s  %d" % [label, ceili(hp)]
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0009
	_tag.font_size = 40
	_tag.outline_size = 10
	_tag.modulate = Color(1.0, 0.85, 0.4)
	_tag.position = Vector3(0, 2.7, 0) * FpsFx.unit
	add_child(_tag)
	if _body_piece != null:
		_set_layers(_body_piece, body_layer(slot))
	_set_layers(_body_pivot, body_layer(slot))
	_set_layers(_tag, body_layer(slot))

func _set_layers(n: Node, mask: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = mask
	for c in n.get_children():
		_set_layers(c, mask)

func _sync_camera() -> void:
	if not _ext_cam or camera == null:
		return
	camera.global_transform = Transform3D(
			Basis.from_euler(Vector3(_pitch, _yaw, _cam_roll)),
			global_position + Vector3(0, EYE_HEIGHT * FpsFx.unit - _cam_drop, 0))

func _update_body(moving: bool) -> void:
	if _body_piece != null and is_instance_valid(_body_piece):
		_body_piece._face_direction(Vector3(-sin(_yaw), 0.0, -cos(_yaw)))
		if moving != _body_walking:
			_body_walking = moving
			_body_piece._play(_body_piece.anim_walk if moving else _body_piece.anim_idle)
	if _body_pivot != null:
		_body_pivot.basis = Basis.from_euler(Vector3(_pitch, 0.0, 0.0))

## ── Input abstraction (keyboard / mouse for slot 0 and classic, arrows / pad for slot 1) ──
func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)

func _pad_ok() -> bool:
	return slot == 1 and Input.get_connected_joypads().size() > 0

func _move_axes() -> Vector2:
	var f := 0.0
	var s := 0.0
	if slot == 1:
		if _key(KEY_UP): f += 1.0
		if _key(KEY_DOWN): f -= 1.0
		if _key(KEY_RIGHT): s += 1.0
		if _key(KEY_LEFT): s -= 1.0
		if _pad_ok():
			var lx := Input.get_joy_axis(_gp_device, JOY_AXIS_LEFT_X)
			var ly := Input.get_joy_axis(_gp_device, JOY_AXIS_LEFT_Y)
			if absf(lx) > 0.2: s += lx
			if absf(ly) > 0.2: f -= ly
	else:
		if _key(KEY_W): f += 1.0
		if _key(KEY_S): f -= 1.0
		if _key(KEY_D): s += 1.0
		if _key(KEY_A): s -= 1.0
	return Vector2(clampf(s, -1.0, 1.0), clampf(f, -1.0, 1.0))

func _sprint_down() -> bool:
	return slot < 0 and _key(KEY_SHIFT)     # Shift is the fire key in two-player duels

func _jump_down() -> bool:
	if slot == 1:
		return _key(KEY_SLASH) or (_pad_ok() and Input.is_joy_button_pressed(_gp_device, JOY_BUTTON_A))
	return _key(KEY_SPACE)

func _fire_down() -> bool:
	if slot == 0:
		return _key(KEY_SHIFT)
	if slot == 1:
		return (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) \
				or (_pad_ok() and (Input.get_joy_axis(_gp_device, JOY_AXIS_TRIGGER_RIGHT) > 0.5
				or Input.is_joy_button_pressed(_gp_device, JOY_BUTTON_RIGHT_SHOULDER)))
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

## Player 2 look: the mouse (see _handle_event); a right stick also works if a pad is connected.
func _apply_slot2_look(delta: float) -> void:
	if not _pad_ok():
		return
	var rx := Input.get_joy_axis(_gp_device, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(_gp_device, JOY_AXIS_RIGHT_Y)
	var turn := 0.0
	var tilt := 0.0
	if absf(rx) > 0.15: turn -= rx * 1.3
	if absf(ry) > 0.15: tilt -= ry
	_look_by(turn * TURN_RATE * delta, tilt * TURN_RATE * 0.7 * delta)

func set_yaw(radians: float) -> void:
	_yaw = radians
	rotation.y = _yaw

## Player 1 of a two-human duel aims with the touchpad's two-finger scroll
## (mouse-wheel events or pan gestures). Flip these if your touchpad uses "natural scrolling".
const P1_WHEEL_STEP := 0.055      # radians per wheel notch
const P1_PAN_SENS := 0.035        # radians per pan-gesture unit
const P1_INVERT_X := false
const P1_INVERT_Y := false

var partner: FpsPlayer = null     # the other human in a split-screen duel

func _unhandled_input(event: InputEvent) -> void:
	if slot == 1:
		return          # player 2 never receives events directly; player 1 forwards them
	_handle_event(event)
	if partner != null:
		partner._handle_event(event)
	if event is InputEventMouseMotion or event is InputEventMouseButton \
			or event is InputEventPanGesture or (event is InputEventKey and (event as InputEventKey).pressed):
		get_viewport().set_input_as_handled()

func _look_by(dyaw: float, dpitch: float) -> void:
	_yaw += dyaw
	_pitch = clampf(_pitch + dpitch, deg_to_rad(-88.0), deg_to_rad(88.0))

func _handle_event(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion:
		# The mouse aims classic players and player 2; player 1 aims with the touchpad scroll.
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled and slot != 0:
			var mm := event as InputEventMouseMotion
			_look_by(-mm.relative.x * MOUSE_SENS, -mm.relative.y * MOUSE_SENS)
	elif event is InputEventPanGesture:
		if slot == 0 and enabled:
			var pg := event as InputEventPanGesture
			var sx := -1.0 if P1_INVERT_X else 1.0
			var sy := -1.0 if P1_INVERT_Y else 1.0
			_look_by(-pg.delta.x * P1_PAN_SENS * sx, -pg.delta.y * P1_PAN_SENS * sy)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var bi := mb.button_index
		var is_wheel := bi == MOUSE_BUTTON_WHEEL_UP or bi == MOUSE_BUTTON_WHEEL_DOWN \
				or bi == MOUSE_BUTTON_WHEEL_LEFT or bi == MOUSE_BUTTON_WHEEL_RIGHT
		if is_wheel:
			if slot == 0 and enabled and mb.pressed:
				var amt := P1_WHEEL_STEP * maxf(mb.factor, 1.0)
				var sx := -1.0 if P1_INVERT_X else 1.0
				var sy := -1.0 if P1_INVERT_Y else 1.0
				match bi:
					MOUSE_BUTTON_WHEEL_LEFT:  _look_by(amt * sx, 0.0)
					MOUSE_BUTTON_WHEEL_RIGHT: _look_by(-amt * sx, 0.0)
					MOUSE_BUTTON_WHEEL_UP:    _look_by(0.0, amt * sy)
					MOUSE_BUTTON_WHEEL_DOWN:  _look_by(0.0, -amt * sy)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and mb.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # click re-captures after Esc
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_R and enabled and slot != 1:
			_start_reload()
		elif key == KEY_ESCAPE and slot != 1:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		velocity.y -= GRAVITY * FpsFx.unit * delta
		move_and_slide()
		_sync_camera()
		return

	if slot == 1 and enabled:
		_apply_slot2_look(delta)
	rotation.y = _yaw
	if _ext_cam:
		_sync_camera()
	else:
		camera.rotation.x = _pitch

	var wish := Vector3.ZERO
	if enabled:
		var ax := _move_axes()
		var basis_y := global_transform.basis
		wish = (-basis_y.z * ax.y + basis_y.x * ax.x)
		if wish.length_squared() > 0.0:
			wish = wish.normalized()
	var speed := float(def["speed"]) * FpsFx.unit
	if enabled and _sprint_down():
		speed *= SPRINT_MULT
	var accel := 16.0 if is_on_floor() else 5.0
	velocity.x = move_toward(velocity.x, wish.x * speed, accel * delta * speed)
	velocity.z = move_toward(velocity.z, wish.z * speed, accel * delta * speed)
	if not is_on_floor():
		velocity.y -= GRAVITY * FpsFx.unit * delta
	elif enabled and _jump_down():
		velocity.y = JUMP_SPEED * FpsFx.unit
	move_and_slide()
	if slot >= 0:
		_update_body(Vector2(velocity.x, velocity.z).length() > 0.5)

	# Viewmodel bob + recoil.
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5 and is_on_floor()
	_bob_t += delta * (9.0 if moving else 2.0)
	var bob_amp := 0.012 if moving else 0.002
	_kick = move_toward(_kick, 0.0, delta * 6.0)
	_view.position = Vector3(0.20 + sin(_bob_t * 0.5) * bob_amp,
			-0.20 + absf(sin(_bob_t)) * bob_amp,
			-0.42 + _kick * 0.06) * FpsFx.unit
	_view.rotation.x = _kick * 0.10
	if _reloading:
		_view.rotation.x = -0.5
		_view.position.y -= 0.06 * FpsFx.unit

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_light.light_energy = 0.0

	# Weapon timers + firing.
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reloading = false
			ammo = int(def["mag"])
			ammo_changed.emit(ammo, int(def["mag"]), false)
	if slot == 1 and enabled:
		var rk := _key(KEY_ENTER) or _key(KEY_KP_ENTER) or (_pad_ok() and Input.is_joy_button_pressed(_gp_device, JOY_BUTTON_X))
		if rk and not _reload_key_was_down:
			_start_reload()
		_reload_key_was_down = rk
	var trigger := enabled and _fire_down()
	if trigger and not _reloading and _cooldown <= 0.0:
		if bool(def["auto"]) or not _trigger_was_down:
			if ammo > 0:
				_fire()
			elif not _trigger_was_down:
				FpsFx.play(_fx_parent, FpsSfx.empty_click(), -6.0)
				_start_reload()
	_trigger_was_down = trigger

func _start_reload() -> void:
	if _reloading or ammo >= int(def["mag"]):
		return
	_reloading = true
	_reload_left = float(def["reload"])
	FpsFx.play(_fx_parent, FpsSfx.reload_click(), -3.0)
	ammo_changed.emit(ammo, int(def["mag"]), true)

func _fire() -> void:
	ammo -= 1
	_cooldown = float(def["interval"])
	_kick = minf(_kick + float(def["recoil"]), 3.0)
	_pitch = clampf(_pitch + deg_to_rad(0.35 * float(def["recoil"])), deg_to_rad(-88.0), deg_to_rad(88.0))
	_flash_light.light_energy = 3.0
	_flash_timer = 0.04
	ammo_changed.emit(ammo, int(def["mag"]), false)
	FpsFx.play(_fx_parent, FpsSfx.shot(String(def["kind"])), 0.0)

	var space := get_world_3d().direct_space_state
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var muzzle_pos := _muzzle.global_position if _muzzle != null else origin + forward * 0.5
	var killed_any := false
	var hit_any := false
	for i in range(int(def["pellets"])):
		var dir := FpsFx.cone_dir(forward, float(def["spread"]))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * MAX_RANGE)
		q.exclude = [get_rid()]
		var res := space.intersect_ray(q)
		var end := origin + dir * MAX_RANGE
		if not res.is_empty():
			end = res["position"]
			var collider: Object = res["collider"]
			if collider != null and collider.has_method("take_damage"):
				var dist := origin.distance_to(end)
				var dmg := float(def["damage"]) * FpsFx.falloff(dist / FpsFx.unit, float(def["range_eff"]))
				var killed: bool = collider.call("take_damage", dmg, end)
				hit_any = true
				killed_any = killed_any or killed
				FpsFx.impact(_fx_parent, end, Color(1.0, 0.3, 0.2))
			else:
				FpsFx.impact(_fx_parent, end)
		FpsFx.tracer(_fx_parent, muzzle_pos, end)
	if hit_any:
		hit_enemy.emit(killed_any)
		FpsFx.play(_fx_parent, FpsSfx.hit_marker(), -8.0)

## Called by the enemy's bullets. Returns true if this hit killed the player.
func take_damage(amount: float, _hit_pos: Vector3) -> bool:
	if dead:
		return false
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if _tag != null:
		_tag.text = "%s  %d" % [_tag_base, ceili(hp)]
	damaged.emit()
	FpsFx.play(_fx_parent, FpsSfx.hurt(), -2.0)
	if hp <= 0.0:
		_die()
		return true
	return false

func _die() -> void:
	dead = true
	enabled = false
	_flash_light.light_energy = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	if _ext_cam:
		tw.tween_property(self, "_cam_drop", (EYE_HEIGHT - 0.35) * FpsFx.unit, 0.6)
		tw.tween_property(self, "_cam_roll", deg_to_rad(65.0), 0.6)
	else:
		tw.tween_property(camera, "position:y", 0.35 * FpsFx.unit, 0.6)
		tw.tween_property(camera, "rotation:z", deg_to_rad(65.0), 0.6)
	_view.visible = false
	if slot >= 0:
		if _tag != null:
			_tag.visible = false
		if _body_pivot != null:
			_body_pivot.visible = false
		if _body_piece != null and is_instance_valid(_body_piece):
			_body_piece.die()
	died.emit()
