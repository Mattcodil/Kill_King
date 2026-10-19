## fps_arena.gd
## One capture duel: a small walled arena with cover, the human's first-person
## player, an AI-controlled opponent, a HUD, a countdown and a time limit.
##
## Usage (see GameController._run_fps_duel):
##   var arena := FpsArena.new()
##   add_child(arena)
##   arena.begin({...})
##   var attacker_won: bool = await arena.duel_finished
##   arena.queue_free()
##
## The arena is built in code (no .tscn) and is meant to be placed far away
## from the chess board so the two never overlap.

class_name FpsArena
extends Node3D

signal duel_finished(attacker_won: bool)

const HALF_X := 16.0
const HALF_Z := 24.0
const WALL_H := 6.0
const COUNTDOWN := 3.0
const TIME_LIMIT := 90.0
const END_DELAY := 2.4
const SPAWN_Z := 13.0

enum _State { COUNTDOWN, FIGHTING, ENDED }

var _state: int = _State.COUNTDOWN
var _t: float = 0.0
var _time_left: float = TIME_LIMIT
var _player_is_attacker: bool = true
var _enemy_name: String = ""
var _player: FpsPlayer = null
var _enemy: FpsEnemy = null
var _hud: FpsHud = null

# Two-human split-screen mode (hot-seat PvP): slot 0 = White's player, slot 1 = Black's.
var _pvp: bool = false
var _pl: Array = []           # [FpsPlayer, FpsPlayer]
var _huds: Array = []         # [FpsHud, FpsHud]
var _attacker_color: int = 0

# In-place mode: the duel is fought on the real chess board and its surroundings.
var _in_place: bool = false
var _spawn_att := Vector3(0, 0.05, -SPAWN_Z)
var _spawn_def := Vector3(0, 0.05, SPAWN_Z)
const IN_PLACE_UNIT := 0.5            # duelists are half human size (same as board pieces)
const IN_PLACE_LIMIT := 6.8           # invisible walls around the board + frame
const BYSTANDER_H := {1: 0.85, 2: 1.05, 3: 1.15, 4: 1.15, 5: 1.25, 6: 1.4}
const BYSTANDER_R := {1: 0.24, 2: 0.34, 3: 0.30, 4: 0.28, 5: 0.32, 6: 0.34}

## Reads the in-place keys of cfg: "in_place", "attacker_pos", "defender_pos" (world
## positions on the board), "bystanders" (Array of {pos: Vector3, type: int}).
func _read_in_place(cfg: Dictionary) -> void:
	_in_place = bool(cfg.get("in_place", false))
	if not _in_place:
		return
	FpsFx.unit = IN_PLACE_UNIT
	var a: Vector3 = cfg["attacker_pos"]
	var d: Vector3 = cfg["defender_pos"]
	a.y = 0.02
	d.y = 0.02
	# Start at least 5 squares apart so nobody spawns in the other's face.
	var flat := Vector3(d.x - a.x, 0.0, d.z - a.z)
	var dist := flat.length()
	var axis := flat.normalized() if dist > 0.01 else Vector3(0, 0, 1)
	var want := 5.0
	if dist < want:
		var push := (want - dist) * 0.5
		a -= axis * push
		d += axis * push
	a.x = clampf(a.x, -5.5, 5.5)
	a.z = clampf(a.z, -5.5, 5.5)
	d.x = clampf(d.x, -5.5, 5.5)
	d.z = clampf(d.z, -5.5, 5.5)
	_spawn_att = a
	_spawn_def = d
	_build_in_place_world(cfg.get("bystanders", []))

func _yaw_towards(from: Vector3, to: Vector3) -> float:
	var dx := to.x - from.x
	var dz := to.z - from.z
	return atan2(-dx, -dz)

## Invisible floor + walls around the table, and a collider for every piece
## still standing on the board so they work as cover.
func _build_in_place_world(bystanders: Array) -> void:
	_add_invisible_block(Vector3(0, -0.5, 0), Vector3(IN_PLACE_LIMIT * 2.0, 1.0, IN_PLACE_LIMIT * 2.0))
	var h := 6.0
	var L := IN_PLACE_LIMIT
	_add_invisible_block(Vector3(0, h * 0.5, -L - 0.5), Vector3(L * 2.0 + 2.0, h, 1.0))
	_add_invisible_block(Vector3(0, h * 0.5, L + 0.5), Vector3(L * 2.0 + 2.0, h, 1.0))
	_add_invisible_block(Vector3(-L - 0.5, h * 0.5, 0), Vector3(1.0, h, L * 2.0))
	_add_invisible_block(Vector3(L + 0.5, h * 0.5, 0), Vector3(1.0, h, L * 2.0))
	for b in bystanders:
		var t: int = int(b["type"])
		var ph: float = float(BYSTANDER_H.get(t, 1.0))
		var pr: float = float(BYSTANDER_R.get(t, 0.3))
		var body := StaticBody3D.new()
		body.position = (b["pos"] as Vector3) + Vector3(0, ph * 0.5, 0)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = pr
		sh.height = ph
		cs.shape = sh
		body.add_child(cs)
		add_child(body)

func _add_invisible_block(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	add_child(body)

## cfg keys: attacker_type, attacker_color, defender_type, defender_color (ints),
## player_is_attacker (bool), piece_scenes (Dictionary PieceType -> PackedScene)
func begin(cfg: Dictionary) -> void:
	var a_type: int = cfg["attacker_type"]
	var a_color: int = cfg["attacker_color"]
	var d_type: int = cfg["defender_type"]
	var d_color: int = cfg["defender_color"]
	_player_is_attacker = cfg["player_is_attacker"]
	var scenes: Dictionary = cfg.get("piece_scenes", {})

	_read_in_place(cfg)
	if not _in_place:
		_build_world()

	_hud = FpsHud.new()
	add_child(_hud)

	var p_type := a_type if _player_is_attacker else d_type
	var e_type := d_type if _player_is_attacker else a_type
	var e_color := d_color if _player_is_attacker else a_color
	_enemy_name = FpsWeaponDefs.piece_name(e_type)

	# Player.
	_player = FpsPlayer.new()
	add_child(_player)
	var p_spawn := _spawn_att if _player_is_attacker else _spawn_def
	var e_spawn := _spawn_def if _player_is_attacker else _spawn_att
	_player.position = p_spawn
	_player.set_yaw(_yaw_towards(p_spawn, e_spawn))
	_player.hp_changed.connect(_hud.set_player_hp)
	_player.ammo_changed.connect(_hud.set_ammo)
	_player.damaged.connect(_hud.flash_damage)
	_player.hit_enemy.connect(_hud.hit_marker)
	_player.died.connect(_on_player_died)
	var p_def := FpsWeaponDefs.get_def(p_type)
	_player.setup(p_def, self)
	_hud.set_weapon(String(p_def["name"]))
	if not _in_place:
		_player.camera.environment = _make_environment()
	_player.camera.make_current()

	# Enemy.
	_enemy = FpsEnemy.new()
	add_child(_enemy)
	_enemy.position = e_spawn
	_enemy.hp_changed.connect(_on_enemy_hp)
	_enemy.died.connect(_on_enemy_died)
	var e_def := FpsWeaponDefs.get_def(e_type)
	_enemy.piece_label = _enemy_name.to_upper()
	_enemy.setup(e_def, scenes.get(e_type) as PackedScene, e_type, e_color, _player, self)
	_hud.set_enemy("%s  (%s)" % [_enemy_name, String(e_def["name"])], _enemy.hp, _enemy.max_hp)

	var a_name := "%s %s" % ["White" if a_color == ChessEnums.PieceColor.WHITE else "Black",
			FpsWeaponDefs.piece_name(a_type)]
	var d_name := "%s %s" % ["White" if d_color == ChessEnums.PieceColor.WHITE else "Black",
			FpsWeaponDefs.piece_name(d_type)]
	var role := "ATTACKING" if _player_is_attacker else "DEFENDING"
	_hud.set_title("%s  attacks  %s     —     you are %s" % [a_name, d_name, role])
	_hud.set_timer(TIME_LIMIT)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Two humans on one computer, split screen. cfg keys as in begin(), minus
## player_is_attacker. Slot 0 is the White player (left), slot 1 the Black player (right).
func begin_pvp(cfg: Dictionary) -> void:
	_pvp = true
	var a_type: int = cfg["attacker_type"]
	var a_color: int = cfg["attacker_color"]
	var d_type: int = cfg["defender_type"]
	var d_color: int = cfg["defender_color"]
	_attacker_color = a_color
	var scenes: Dictionary = cfg.get("piece_scenes", {})
	_read_in_place(cfg)
	if not _in_place:
		_build_world()

	# Black backdrop + two side-by-side viewports sharing this 3D world.
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(row)

	var types: Array[int] = [0, 0]
	var colors: Array[int] = [ChessEnums.PieceColor.WHITE, ChessEnums.PieceColor.BLACK]
	types[a_color] = a_type
	types[d_color] = d_type
	var hints: Array[String] = [
		"WASD move  ·  Touchpad two-finger scroll = aim  ·  Shift fire  ·  R reload  ·  Space jump",
		"Arrow keys move  ·  Mouse aim  ·  Right-click fire  ·  Enter reload  ·  / jump",
	]
	for i in range(2):
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(svc)
		var sub := SubViewport.new()
		sub.world_3d = get_world_3d()
		sub.handle_input_locally = false
		sub.audio_listener_enable_3d = (i == 0)
		svc.add_child(sub)

		var pl := FpsPlayer.new()
		add_child(pl)
		var atk := (colors[i] == a_color)
		var my_spawn := _spawn_att if atk else _spawn_def
		var their_spawn := _spawn_def if atk else _spawn_att
		pl.position = my_spawn
		pl.set_yaw(_yaw_towards(my_spawn, their_spawn))
		var def := FpsWeaponDefs.get_def(types[i])
		pl.setup(def, self)
		var cname := "White" if colors[i] == ChessEnums.PieceColor.WHITE else "Black"
		var label := "%s %s" % [cname, FpsWeaponDefs.piece_name(types[i])]
		pl.setup_pvp(i, sub, scenes.get(types[i]) as PackedScene, types[i], colors[i], label)
		if not _in_place:
			pl.camera.environment = _make_environment()
		pl.camera.current = true
		pl.died.connect(_on_pvp_died.bind(i))
		_pl.append(pl)

		var h := FpsHud.new()
		sub.add_child(h)
		h.set_weapon(String(def["name"]))
		pl.hp_changed.connect(h.set_player_hp)
		pl.ammo_changed.connect(h.set_ammo)
		pl.damaged.connect(h.flash_damage)
		pl.hit_enemy.connect(h.hit_marker)
		_huds.append(h)

	(_pl[0] as FpsPlayer).partner = _pl[1]
	for i in range(2):
		var other: FpsPlayer = _pl[1 - i]
		var h2: FpsHud = _huds[i]
		var opp_name := "%s %s" % ["White" if colors[1 - i] == ChessEnums.PieceColor.WHITE else "Black",
				FpsWeaponDefs.piece_name(types[1 - i])]
		h2.set_enemy(opp_name, other.hp, other.max_hp)
		other.hp_changed.connect(func(c: float, m: float) -> void: h2.set_enemy(opp_name, c, m))
		var role := "ATTACKING" if colors[i] == a_color else "DEFENDING"
		h2.set_title("%s   —   you are %s" % [("White" if i == 0 else "Black") + " player", role])
		h2.set_timer(TIME_LIMIT)
		h2.show_banner("Get ready", hints[i], Color(1, 0.9, 0.5))
		_pl[i].camera.make_current()   # (each lives in its own viewport)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_pvp_died(slot_i: int) -> void:
	# The attacker wins when the defender (the other colour) dies.
	var dead_color := ChessEnums.PieceColor.WHITE if slot_i == 0 else ChessEnums.PieceColor.BLACK
	_finish(dead_color != _attacker_color)

func _exit_tree() -> void:
	FpsFx.unit = 1.0
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var _debug_on: bool = false
var _f3_was_down: bool = false
var _debug_timer: float = 0.0

func _process(delta: float) -> void:
	if _pvp:
		_process_pvp(delta)
		return
	if _hud == null:
		return
	# F3 toggles a small debug line (enemy distance / size / visibility).
	var f3 := Input.is_physical_key_pressed(KEY_F3)
	if f3 and not _f3_was_down:
		_debug_on = not _debug_on
		if not _debug_on:
			_hud.set_debug("")
	_f3_was_down = f3
	if _debug_on:
		_debug_timer -= delta
		if _debug_timer <= 0.0:
			_debug_timer = 0.25
			_hud.set_debug(_enemy.debug_text())
	match _state:
		_State.COUNTDOWN:
			_t += delta
			var left := COUNTDOWN - _t
			if left > 0.0:
				_hud.show_banner(str(int(ceil(left))), "Get ready", Color(1, 0.9, 0.5))
			else:
				_state = _State.FIGHTING
				_player.enabled = true
				_enemy.active = true
				_hud.show_banner("FIGHT!", "", Color(1, 0.4, 0.3))
				get_tree().create_timer(0.8).timeout.connect(func() -> void:
					if _state == _State.FIGHTING and _hud != null:
						_hud.clear_banner())
		_State.FIGHTING:
			_time_left -= delta
			_hud.set_timer(_time_left)
			if _time_left <= 0.0:
				# Nobody won in time: the defender holds the square.
				_finish(false, "TIME UP")

func _process_pvp(delta: float) -> void:
	match _state:
		_State.COUNTDOWN:
			_t += delta
			var left := COUNTDOWN - _t
			if left > 0.0:
				for h: FpsHud in _huds:
					h.show_banner(str(int(ceil(left))), "Get ready", Color(1, 0.9, 0.5))
			else:
				_state = _State.FIGHTING
				for p: FpsPlayer in _pl:
					p.enabled = true
				for h: FpsHud in _huds:
					h.show_banner("FIGHT!", "", Color(1, 0.4, 0.3))
				get_tree().create_timer(0.8).timeout.connect(func() -> void:
					if _state == _State.FIGHTING:
						for h: FpsHud in _huds:
							h.clear_banner())
		_State.FIGHTING:
			_time_left -= delta
			for h: FpsHud in _huds:
				h.set_timer(_time_left)
			if _time_left <= 0.0:
				_finish(false, "TIME UP")

func _on_enemy_hp(cur: float, max_hp: float) -> void:
	_hud.set_enemy(_enemy_name, cur, max_hp)

func _on_player_died() -> void:
	# If the player was attacking, the attack failed. If defending, the capture succeeds.
	_finish(not _player_is_attacker)

func _on_enemy_died() -> void:
	_finish(_player_is_attacker)

func _finish(attacker_won: bool, reason: String = "") -> void:
	if _state == _State.ENDED:
		return
	_state = _State.ENDED
	if _pvp:
		for p: FpsPlayer in _pl:
			p.enabled = false
		var title := "CAPTURE!" if attacker_won else "ATTACK REPELLED"
		var sub_txt := "The defending piece is eliminated" if attacker_won else "The attacker failed — turn lost"
		if reason != "":
			sub_txt = reason + " — " + sub_txt
		var col := Color(0.4, 1.0, 0.4) if attacker_won else Color(1.0, 0.35, 0.3)
		for h: FpsHud in _huds:
			h.show_banner(title, sub_txt, col)
		await get_tree().create_timer(END_DELAY).timeout
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		duel_finished.emit(attacker_won)
		return
	_player.enabled = false
	_enemy.active = false
	if attacker_won:
		_hud.show_banner("CAPTURE!", "The defending piece is eliminated", Color(0.4, 1.0, 0.4))
	else:
		var sub := "The attacker failed — turn lost"
		if reason != "":
			sub = reason + " — " + sub
		_hud.show_banner("ATTACK REPELLED", sub, Color(1.0, 0.35, 0.3))
	await get_tree().create_timer(END_DELAY).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	duel_finished.emit(attacker_won)

# ── World construction ─────────────────────────────────────────────────────
func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return env

func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	# Floor and walls.
	_add_block(Vector3(0, -0.5, 0), Vector3(HALF_X * 2.0, 1.0, HALF_Z * 2.0), Color(0.30, 0.33, 0.28))
	var wall_col := Color(0.46, 0.43, 0.38)
	_add_block(Vector3(0, WALL_H * 0.5, -HALF_Z - 0.5), Vector3(HALF_X * 2.0 + 2.0, WALL_H, 1.0), wall_col)
	_add_block(Vector3(0, WALL_H * 0.5, HALF_Z + 0.5), Vector3(HALF_X * 2.0 + 2.0, WALL_H, 1.0), wall_col)
	_add_block(Vector3(-HALF_X - 0.5, WALL_H * 0.5, 0), Vector3(1.0, WALL_H, HALF_Z * 2.0), wall_col)
	_add_block(Vector3(HALF_X + 0.5, WALL_H * 0.5, 0), Vector3(1.0, WALL_H, HALF_Z * 2.0), wall_col)

	# Cover. Defined for one half, then mirrored through the centre so both
	# sides get exactly the same layout (x, z, size_x, size_y, size_z).
	var cover: Array = [
		[-6.0, -8.0, 3.5, 1.3, 1.0],
		[6.0, -12.0, 1.0, 2.4, 3.0],
		[0.0, -4.0, 2.2, 1.1, 2.2],
		[-11.0, -14.0, 1.0, 2.2, 4.0],
		[10.0, -5.0, 3.0, 1.3, 1.0],
		[-3.0, -16.0, 1.6, 2.2, 1.6],
	]
	var colors: Array[Color] = [Color(0.45, 0.30, 0.16), Color(0.52, 0.52, 0.50)]
	for i in range(cover.size()):
		var c: Array = cover[i]
		var size := Vector3(c[2], c[3], c[4])
		var col: Color = colors[i % 2]
		_add_block(Vector3(c[0], size.y * 0.5, c[1]), size, col)
		_add_block(Vector3(-float(c[0]), size.y * 0.5, -float(c[1])), size, col)

func _add_block(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	mi.material_override = m
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
