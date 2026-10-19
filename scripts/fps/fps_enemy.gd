## fps_enemy.gd
## Computer-controlled opponent in a capture duel. Uses the real chess-piece
## model, the piece's weapon stats, and a simple "chase, strafe, shoot in
## bursts, reload" behaviour. Tune the AI_* constants to change difficulty.

class_name FpsEnemy
extends CharacterBody3D

signal hp_changed(cur: float, max_hp: float)
signal died

# ── Difficulty knobs ───────────────────────────────────────────────────────
const AI_DAMAGE_MULT := 0.75       # enemy bullets do this fraction of weapon damage
const AI_AIM_ERROR_DEG := 3.0      # extra aim error on top of weapon spread
const AI_FIRE_SLOWDOWN := 1.35     # enemy fires this much slower than the weapon allows
const AI_REACTION_TIME := 0.45     # seconds between spotting the player and shooting
const AI_SPEED_MULT := 0.85
## The chess board shows pieces at scale 0.05 (about one board square tall).
## In the arena they are drawn at twice that, which is roughly human size.
## Scaling by a fixed factor (like the board does) is safer than measuring the
## mesh, because the real models are skinned and their mesh bounds are unreliable.
const PIECE_SCALE := 0.10
const GRAVITY := 22.0

## Where the enemy's gun floats, relative to a pivot at chest height that
## always turns to face the player. It has to sit well in front of the body or
## it disappears inside the wide pieces (rook, queen) and is not drawn.
const GUN_FORWARD := 0.95    # metres in front of the chest
const GUN_RIGHT := 0.30      # metres to the right
const GUN_SCALE := 1.8       # real guns look tiny on a 2 m piece

var def: Dictionary = {}
var hp: float = 100.0
var max_hp: float = 100.0
var active: bool = false
var dead: bool = false
var target: FpsPlayer = null

var _piece: BasePiece = null
var _gun_pivot: Node3D = null
var _gun: Node3D = null
var _muzzle: Node3D = null
var _fx_parent: Node = null
var _ammo: int = 0
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _burst_left: int = 0
var _burst_pause: float = 0.0
var _los: bool = false
var _los_timer: float = 0.0
var _seen_for: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 1.0
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _anim_is_walk: bool = false
var _tag: Label3D = null
var piece_label: String = ""

func setup(weapon_def: Dictionary, piece_scene: PackedScene, piece_type: int,
		piece_color: int, player: FpsPlayer, fx_parent: Node) -> void:
	def = weapon_def
	target = player
	_fx_parent = fx_parent
	max_hp = float(def["hp"])
	hp = max_hp
	_ammo = int(def["mag"])

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var u := FpsFx.unit
	cap.radius = 0.4 * u
	cap.height = 1.8 * u
	col.shape = cap
	col.position = Vector3(0, 0.9 * u, 0)
	add_child(col)

	if piece_scene != null:
		_piece = piece_scene.instantiate() as BasePiece
	if _piece != null:
		_piece.piece_type = piece_type
		_piece.piece_color = piece_color
		_piece.use_weapon = false       # no sword — this piece carries a gun
		_piece.scale = Vector3.ONE * PIECE_SCALE * u   # before add_child, like GameController does
		add_child(_piece)
		_piece.position = Vector3.ZERO
	else:
		# Fallback if the piece scene is missing: a plain capsule.
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.4 * u
		cm.height = 1.8 * u
		mi.mesh = cm
		mi.position = Vector3(0, 0.9 * u, 0)
		add_child(mi)

	# The pivot turns to aim at the player; the gun sits slightly right of and in front of it.
	_gun_pivot = Node3D.new()
	_gun_pivot.position = Vector3(0, 1.15, 0) * u
	add_child(_gun_pivot)
	_gun = FpsWeaponModels.build(String(def["kind"]))
	_gun.position = Vector3(GUN_RIGHT, 0.0, -GUN_FORWARD) * u
	_gun.scale = Vector3.ONE * GUN_SCALE * u
	_gun_pivot.add_child(_gun)
	_muzzle = _gun.get_node_or_null("Muzzle") as Node3D
	_last_pos = global_position

	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0009
	_tag.font_size = 40
	_tag.outline_size = 10
	_tag.modulate = Color(1.0, 0.45, 0.35)
	_tag.position = Vector3(0, 2.7, 0) * u
	add_child(_tag)
	_update_tag()

## Debug text for the F3 overlay: where the enemy is and how big its model is.
func debug_text() -> String:
	var h := 0.0
	if _piece != null and is_instance_valid(_piece):
		var box := _combined_aabb(_piece)
		h = box.size.y * _piece.scale.y
	var d := 0.0
	if target != null and is_instance_valid(target):
		d = global_position.distance_to(target.global_position)
	return "enemy: dist %.1f m | model height ~%.2f m | scale %.3f | visible %s | los %s" % [
		d, h, _piece.scale.y if _piece != null else 0.0,
		str(_piece.is_visible_in_tree()) if _piece != null else "no piece", str(_los)]

func _combined_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.name != "BlobShadow" and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var rel := root.global_transform.affine_inverse() * mi.global_transform
			var tb := rel * mi.get_aabb()
			if first:
				result = tb
				first = false
			else:
				result = result.merge(tb)
		for c in n.get_children():
			stack.append(c)
	return result

func take_damage(amount: float, _hit_pos: Vector3) -> bool:
	if dead:
		return false
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	_update_tag()
	if hp <= 0.0:
		_die()
		return true
	return false

func _update_tag() -> void:
	if _tag != null:
		_tag.text = "%s  %d" % [piece_label, ceili(hp)]

func _die() -> void:
	dead = true
	active = false
	if _tag != null:
		_tag.visible = false
	if _gun_pivot != null:
		_gun_pivot.visible = false
	var shape := get_child(0) as CollisionShape3D
	if shape != null:
		shape.set_deferred("disabled", true)
	if _piece != null and is_instance_valid(_piece):
		_piece.die()
	died.emit()

func _physics_process(delta: float) -> void:
	if dead or target == null or not is_instance_valid(target):
		return
	var to_player := target.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var dir := to_player.normalized() if dist > 0.01 else Vector3.FORWARD

	# Face the player.
	if _piece != null and is_instance_valid(_piece):
		_piece._face_direction(dir)
	if _gun_pivot != null and _gun_pivot.global_position.distance_to(_aim_point()) > 0.1:
		_gun_pivot.look_at(_aim_point(), Vector3.UP)

	# Line of sight check (throttled).
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = 0.1
		_los = _has_los()
	if _los and active:
		_seen_for += delta
	else:
		_seen_for = 0.0

	var move := Vector3.ZERO
	if active and not target.dead:
		var pref := float(def["pref_range"]) * FpsFx.unit
		var band := 3.0 * FpsFx.unit
		if not _los:
			move = dir
			# Stuck behind cover? Sidestep.
			if global_position.distance_to(_last_pos) < 0.02 * FpsFx.unit:
				_stuck_timer += delta
			else:
				_stuck_timer = 0.0
			if _stuck_timer > 0.4:
				move = dir.cross(Vector3.UP) * _strafe_dir
		else:
			if dist > pref + band:
				move += dir
			elif dist < pref - band:
				move -= dir * 0.8
			move += dir.cross(Vector3.UP) * _strafe_dir * 0.8
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(0.8, 2.2)
			_strafe_dir = -_strafe_dir if randf() < 0.6 else _strafe_dir
		if move.length_squared() > 0.0:
			move = move.normalized()
	_last_pos = global_position

	var speed := float(def["speed"]) * AI_SPEED_MULT * FpsFx.unit
	velocity.x = move.x * speed
	velocity.z = move.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * FpsFx.unit * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_update_anim(move.length_squared() > 0.01)

	_update_weapon(delta)

func _update_anim(walking: bool) -> void:
	if _piece == null or not is_instance_valid(_piece) or walking == _anim_is_walk:
		return
	_anim_is_walk = walking
	_piece._play(_piece.anim_walk if walking else _piece.anim_idle)

func _eye_pos() -> Vector3:
	return global_position + Vector3(0, 1.5 * FpsFx.unit, 0)

func _aim_point() -> Vector3:
	return target.global_position + Vector3(0, 1.2 * FpsFx.unit, 0)

func _has_los() -> bool:
	var q := PhysicsRayQueryParameters3D.create(_eye_pos(), _aim_point())
	q.exclude = [get_rid()]
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	return not res.is_empty() and res["collider"] == target

func _update_weapon(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_burst_pause = maxf(_burst_pause - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_ammo = int(def["mag"])
		return
	if not active or not _los or target.dead:
		return
	if _ammo <= 0:
		_reload_left = float(def["reload"])
		FpsFx.play(_fx_parent, FpsSfx.reload_click(), -4.0, global_position)
		return
	if _seen_for < AI_REACTION_TIME or _cooldown > 0.0 or _burst_pause > 0.0:
		return
	_shoot()

func _shoot() -> void:
	_ammo -= 1
	_cooldown = float(def["interval"]) * AI_FIRE_SLOWDOWN
	if bool(def["auto"]):
		if _burst_left <= 0:
			_burst_left = randi_range(3, 8)
		_burst_left -= 1
		if _burst_left <= 0:
			_burst_pause = randf_range(0.5, 1.1)
	else:
		_cooldown += randf_range(0.0, 0.25)

	var origin := _eye_pos()
	var muzzle_pos := _muzzle.global_position if _muzzle != null else origin
	var base_dir := (_aim_point() - origin).normalized()
	FpsFx.play(_fx_parent, FpsSfx.shot(String(def["kind"])), -2.0, muzzle_pos)
	var space := get_world_3d().direct_space_state
	for i in range(int(def["pellets"])):
		var dir := FpsFx.cone_dir(base_dir, float(def["spread"]) + AI_AIM_ERROR_DEG)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 150.0)
		q.exclude = [get_rid()]
		var res := space.intersect_ray(q)
		var end := origin + dir * 150.0
		if not res.is_empty():
			end = res["position"]
			var collider: Object = res["collider"]
			if collider == target:
				var dmg := float(def["damage"]) * AI_DAMAGE_MULT \
						* FpsFx.falloff(origin.distance_to(end) / FpsFx.unit, float(def["range_eff"]))
				target.take_damage(dmg, end)
			else:
				FpsFx.impact(_fx_parent, end)
		FpsFx.tracer(_fx_parent, muzzle_pos, end, Color(1.0, 0.5, 0.3))
