## qajar_figure.gd
## Code-built, low-poly Qajar-era chess figure (no external assets).
## Put it on the "Model" child of a BasePiece scene; it reads the parent's
## piece_type / piece_color, builds the meshes and an AnimationPlayer with the
## clips BasePiece expects: idle, walk, attack, death (+ jump for the knight).
##
## Raw size: 1 raw unit = 0.05 world units at the board piece scale, so a pawn
## is ~16 units (0.8 world) and the king ~27 (1.35 world). Front of the figure
## is +Z (BasePiece rotates it with model_forward_deg = 180).
##
## Armies: white = "Turquoise army" (فیروزه), black = "Lacquer army" (لاکی).

class_name QajarFigure
extends Node3D

const TURQUOISE      := Color(0.08, 0.66, 0.68)
const TURQUOISE_DARK := Color(0.04, 0.40, 0.44)
const LACQUER        := Color(0.50, 0.07, 0.06)
const LACQUER_DARK   := Color(0.22, 0.03, 0.03)
const GOLD           := Color(0.93, 0.74, 0.22)
const SKIN           := Color(0.86, 0.66, 0.50)
const HAT_BLACK      := Color(0.10, 0.08, 0.07)
const CREAM          := Color(0.93, 0.89, 0.78)
const STEEL          := Color(0.72, 0.74, 0.78)
const WOOD           := Color(0.38, 0.22, 0.10)
const BOOT           := Color(0.14, 0.09, 0.06)

var _kind: int = ChessEnums.PieceType.PAWN
var _is_white: bool = true
var _main: Color = TURQUOISE
var _dark: Color = TURQUOISE_DARK
var _mats: Dictionary = {}

var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _weapon: Node3D
var _flash: MeshInstance3D
var _horse_legs: Array[Node3D] = []
var _anim_player: AnimationPlayer
var _weapon_kind: String = "musket"
var _hip_y: float = 8.0

func _ready() -> void:
	var p := get_parent()
	if p != null:
		var t: Variant = p.get("piece_type")
		var c: Variant = p.get("piece_color")
		if t != null:
			_kind = int(t)
		if c != null:
			_is_white = int(c) == ChessEnums.PieceColor.WHITE
	_main = TURQUOISE if _is_white else LACQUER
	_dark = TURQUOISE_DARK if _is_white else LACQUER_DARK
	_build()
	_build_animations()
	print("[QajarFigure] kind=%d white=%s meshes=%d" % [_kind, str(_is_white), _count_meshes(self)])

# ── Primitive helpers ──────────────────────────────────────────────────────
func _mat(c: Color, metallic: float = 0.0, rough: float = 0.75) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(), metallic, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	metallic = minf(metallic, 0.4)
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	m.resource_name = "qajar_" + c.to_html(false)
	_mats[key] = m
	return m

func _node(parent: Node3D, nm: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	return n

func _mesh(parent: Node3D, m: Mesh, pos: Vector3, c: Color, metallic: float = 0.0, rough: float = 0.75) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c, metallic, rough)
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, metallic: float = 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, pos, c, metallic)

func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, sides: int = 10, metallic: float = 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return _mesh(parent, m, pos, c, metallic)

func _sph(parent: Node3D, r: float, pos: Vector3, c: Color, squash: float = 1.0, metallic: float = 0.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * squash
	m.radial_segments = 12
	m.rings = 6
	return _mesh(parent, m, pos, c, metallic)

# ── Building ───────────────────────────────────────────────────────────────
func _build() -> void:
	match _kind:
		ChessEnums.PieceType.PAWN:   _build_pawn()
		ChessEnums.PieceType.ROOK:   _build_rook()
		ChessEnums.PieceType.KNIGHT: _build_knight()
		ChessEnums.PieceType.BISHOP: _build_bishop()
		ChessEnums.PieceType.QUEEN:  _build_queen()
		ChessEnums.PieceType.KING:   _build_king()
		_:                           _build_pawn()

## Shared humanoid: legs, coat, sash, head, arms. Returns the head-top y.
## coat_h = coat height above the hips, skirt = flared coat skirt (long robes).
func _humanoid(hip: float, coat_h: float, width: float, skirt: float, skirt_r: float, arm_len: float, mustache: bool = true) -> float:
	_hip_y = hip
	_body = _node(self, "Body")
	# Legs (pivot at the hip so they can swing)
	_leg_l = _node(_body, "LegL", Vector3(-width * 0.28, hip, 0))
	_leg_r = _node(_body, "LegR", Vector3(width * 0.28, hip, 0))
	for leg in [_leg_l, _leg_r]:
		_box(leg, Vector3(width * 0.32, hip * 0.78, width * 0.34), Vector3(0, -hip * 0.39, 0), CREAM)
		_box(leg, Vector3(width * 0.36, hip * 0.26, width * 0.55), Vector3(0, -hip * 0.87, width * 0.08), BOOT)
	# Coat
	_box(_body, Vector3(width, coat_h, width * 0.62), Vector3(0, hip + coat_h * 0.5, 0), _main)
	if skirt > 0.0:
		_cyl(_body, width * 0.58, skirt_r, skirt, Vector3(0, hip + skirt * 0.1, 0), _main, 12)
	# Sash (kamarband) + gold buckle
	_box(_body, Vector3(width * 1.06, coat_h * 0.16, width * 0.68), Vector3(0, hip + coat_h * 0.2, 0), _dark)
	_box(_body, Vector3(width * 0.2, coat_h * 0.16, width * 0.1), Vector3(0, hip + coat_h * 0.2, width * 0.36), GOLD, 0.6)
	# Gold chest trim (buttons strip)
	_box(_body, Vector3(width * 0.12, coat_h * 0.62, width * 0.06), Vector3(0, hip + coat_h * 0.62, width * 0.33), GOLD, 0.5)
	# Head
	var neck_y := hip + coat_h
	_head = _node(_body, "Head", Vector3(0, neck_y + width * 0.05, 0))
	_sph(_head, width * 0.34, Vector3(0, width * 0.3, 0), SKIN)
	_face(_head, width, mustache)
	# Arms (pivot at the shoulder)
	var sh_y := hip + coat_h * 0.92
	_arm_l = _node(_body, "ArmL", Vector3(-width * 0.62, sh_y, 0))
	_arm_r = _node(_body, "ArmR", Vector3(width * 0.62, sh_y, 0))
	for arm in [_arm_l, _arm_r]:
		_box(arm, Vector3(width * 0.26, arm_len, width * 0.28), Vector3(0, -arm_len * 0.5, 0), _main)
		_sph(arm, width * 0.15, Vector3(0, -arm_len - width * 0.05, 0), SKIN)
		_cyl(arm, width * 0.17, width * 0.17, width * 0.08, Vector3(0, -arm_len + width * 0.04, 0), GOLD, 8, 0.5)
	# Epaulettes
	_box(_body, Vector3(width * 0.34, width * 0.07, width * 0.38), Vector3(-width * 0.6, sh_y + width * 0.12, 0), GOLD, 0.6)
	_box(_body, Vector3(width * 0.34, width * 0.07, width * 0.38), Vector3(width * 0.6, sh_y + width * 0.12, 0), GOLD, 0.6)
	return neck_y + width * 0.05 + width * 0.64


## Face details on a head pivot: eyes, brows, nose and (optionally) a thick
## curled Qajar moustache. The queen gets lips and no moustache.
func _face(head: Node3D, w: float, mustache: bool) -> void:
	for sx in [-1.0, 1.0]:
		_box(head, Vector3(w * 0.12, w * 0.09, w * 0.05), Vector3(sx * w * 0.13, w * 0.37, w * 0.31), Color(0.97, 0.97, 0.95))  # eye white
		_box(head, Vector3(w * 0.06, w * 0.07, w * 0.06), Vector3(sx * w * 0.13, w * 0.37, w * 0.325), HAT_BLACK)             # pupil
		var brow := _box(head, Vector3(w * 0.19, w * 0.05, w * 0.06), Vector3(sx * w * 0.14, w * 0.47, w * 0.31), HAT_BLACK)    # brow
		brow.rotation_degrees.z = -sx * 8.0
	_box(head, Vector3(w * 0.09, w * 0.15, w * 0.12), Vector3(0, w * 0.29, w * 0.35), Color(0.80, 0.58, 0.43))                   # nose
	if mustache:
		_box(head, Vector3(w * 0.40, w * 0.08, w * 0.09), Vector3(0, w * 0.18, w * 0.335), HAT_BLACK)                              # moustache bar
		for sx in [-1.0, 1.0]:
			var tip := _box(head, Vector3(w * 0.17, w * 0.06, w * 0.08), Vector3(sx * w * 0.25, w * 0.215, w * 0.325), HAT_BLACK)  # curled tip
			tip.rotation_degrees.z = sx * 28.0
	else:
		_box(head, Vector3(w * 0.16, w * 0.05, w * 0.06), Vector3(0, w * 0.18, w * 0.345), Color(0.78, 0.18, 0.22))               # lips
		for sx in [-1.0, 1.0]:
			_sph(head, w * 0.05, Vector3(sx * w * 0.35, w * 0.12, w * 0.0), GOLD, 1.0, 0.5)                                          # earrings

func _make_weapon(kind: String, pos: Vector3, scale_f: float = 1.0) -> void:
	_weapon_kind = kind
	_weapon = _node(_body, "Weapon", pos)
	var w := _weapon
	match kind:
		"musket", "heavy", "rifle":
			var blen := 15.0
			var th := 0.9
			if kind == "heavy":
				blen = 17.0
				th = 1.5
			elif kind == "rifle":
				blen = 16.0
				th = 0.8
			blen *= scale_f
			_box(w, Vector3(th * 1.3, th * 1.8, blen * 0.28), Vector3(0, -th * 0.4, -blen * 0.30), WOOD)      # stock
			_box(w, Vector3(th, th, blen * 0.55), Vector3(0, 0, blen * 0.14), WOOD)                          # forestock
			_box(w, Vector3(th * 0.7, th * 0.7, blen * 0.62), Vector3(0, th * 0.35, blen * 0.2), STEEL, 0.8) # barrel
			_box(w, Vector3(th * 0.5, th * 0.5, th * 0.8), Vector3(0, th * 1.1, -blen * 0.05), STEEL, 0.8)  # lock
			if kind == "musket":
				_box(w, Vector3(th * 0.3, th * 0.3, blen * 0.28), Vector3(0, th * 0.35, blen * 0.64), STEEL, 0.9) # bayonet
			_flash = _sph(w, th * 1.4, Vector3(0, th * 0.35, blen * 0.62), Color(1.0, 0.85, 0.3))
			_flash.visible = false
		"pistol":
			_box(w, Vector3(1.2, 2.6, 1.4), Vector3(0, -1.6, -1.2), WOOD)
			_box(w, Vector3(1.0, 1.0, 5.2), Vector3(0, 0.0, 1.2), STEEL, 0.8)
			_flash = _sph(w, 1.4, Vector3(0, 0, 4.2), Color(1.0, 0.85, 0.3))
			_flash.visible = false
		"sword":
			_box(w, Vector3(1.0, 1.0, 3.0), Vector3(0, 0, -1.5), WOOD)                   # grip
			_box(w, Vector3(0.7, 4.0, 0.9), Vector3(0, 0, 0.0), GOLD, 0.7)                # guard
			_box(w, Vector3(0.55, 1.5, 11.0 * scale_f), Vector3(0, 0, 6.0 * scale_f), STEEL, 0.9)   # blade
			var tip := _box(w, Vector3(0.55, 1.5, 3.2), Vector3(0, -0.5, 12.8 * scale_f), STEEL, 0.9)  # curved tip (shamshir)
			tip.rotation_degrees.x = 18.0

## Diagonal ammunition strap across the chest with small gold cartridge caps.
func _cross_belt(width: float, hip: float, coat_h: float) -> void:
	var strap := _box(_body, Vector3(width * 0.16, coat_h * 0.95, width * 0.08), Vector3(0, hip + coat_h * 0.55, width * 0.34), BOOT)
	strap.rotation_degrees.z = 28.0
	for i in range(4):
		var t := (float(i) - 1.5) * coat_h * 0.2
		_box(_body, Vector3(width * 0.1, width * 0.1, width * 0.1), Vector3(-t * 0.47, hip + coat_h * 0.55 + t * 0.88, width * 0.4), GOLD, 0.5)

func _hat_kolah(y: float, w: float, h: float) -> void:
	# Tall Qajar lambskin hat with a coloured band and a small gold badge.
	_cyl(_head, w * 0.46, w * 0.40, h, Vector3(0, y + h * 0.5, 0), HAT_BLACK, 12)
	_cyl(_head, w * 0.47, w * 0.47, h * 0.16, Vector3(0, y + h * 0.1, 0), _main, 12)
	_box(_head, Vector3(w * 0.16, w * 0.16, w * 0.06), Vector3(0, y + h * 0.1, w * 0.46), GOLD, 0.7)

func _pigment_beard(w: float, length: float) -> void:
	_box(_head, Vector3(w * 0.52, length, w * 0.3), Vector3(0, w * 0.12 - length * 0.5, w * 0.2), HAT_BLACK)

# ── The six pieces ─────────────────────────────────────────────────────────
func _build_pawn() -> void:
	# Foot soldier with a flintlock musket + bayonet and a tall kolah hat.
	_humanoid(5.0, 5.6, 5.2, 0.0, 0.0, 4.4)
	_hat_kolah(4.2, 5.2, 4.8)
	_cross_belt(5.2, 5.0, 5.6)
	_make_weapon("musket", Vector3(2.6, 9.0, 2.0))

func _build_rook() -> void:
	# Heavy, broad fort-guard with a crenellated helmet and a big blunderbuss-musket.
	_humanoid(5.6, 7.4, 8.2, 3.0, 5.6, 5.6)
	# Crenellated tower-helmet (reads as a rook on the board)
	_cyl(_head, 4.0, 4.4, 4.6, Vector3(0, 6.4, 0), _dark, 12)
	for i in range(6):
		var a := TAU * float(i) / 6.0
		_box(_head, Vector3(1.8, 1.9, 1.8), Vector3(sin(a) * 3.5, 9.6, cos(a) * 3.5), _main)
	_cyl(_head, 4.5, 4.5, 0.8, Vector3(0, 4.3, 0), GOLD, 12, 0.6)
	_cross_belt(8.2, 5.6, 7.4)
	# Shoulder plates
	_box(_body, Vector3(3.2, 1.0, 3.6), Vector3(-5.2, 13.8, 0), _dark, 0.3)
	_box(_body, Vector3(3.2, 1.0, 3.6), Vector3(5.2, 13.8, 0), _dark, 0.3)
	_make_weapon("heavy", Vector3(4.2, 10.5, 2.4))

func _build_bishop() -> void:
	# Cleric in a long robe with a big round turban and a crescent staff.
	_humanoid(4.5, 8.0, 5.6, 9.0, 4.8, 6.0)
	# long robe covers legs
	_cyl(_body, 3.2, 4.8, 8.6, Vector3(0, 4.4, 0), _main, 12)
	# Turban: squashed sphere + wrapped band + gold jewel
	_sph(_head, 4.0, Vector3(0, 6.6, 0), CREAM, 0.75)
	_cyl(_head, 4.2, 4.2, 1.3, Vector3(0, 5.2, 0), _dark, 12)
	_sph(_head, 0.8, Vector3(0, 6.4, 3.8), GOLD, 1.0, 0.7)
	_cyl(_head, 0.3, 0.3, 2.4, Vector3(0, 9.0, 0), GOLD, 6, 0.6)
	_pigment_beard(5.6, 3.6)
	# Staff held in the right hand (a "weapon" pivot so it can poke on attack)
	_weapon_kind = "staff"
	_weapon = _node(_body, "Weapon", Vector3(3.8, 10.0, 2.2))
	_box(_weapon, Vector3(0.7, 0.7, 20.0), Vector3(0, 0, 4.0), WOOD)
	var crescent := _cyl(_weapon, 1.6, 1.6, 0.6, Vector3(0, 0, 14.4), GOLD, 10, 0.7)
	crescent.rotation_degrees.x = 90.0
	# Pistol tucked in the sash
	var pist := _node(_body, "Pistol", Vector3(-2.6, 7.8, 3.0))
	_box(pist, Vector3(1.0, 2.4, 1.2), Vector3(0, -1.2, 0), WOOD)
	_box(pist, Vector3(0.8, 0.8, 4.0), Vector3(0, 0, 1.6), STEEL, 0.8)
	_flash = _sph(_weapon, 1.4, Vector3(0, 0, 15.0), Color(1.0, 0.85, 0.3))
	_flash.visible = false

func _build_queen() -> void:
	# Qajar noblewoman-warrior: wide flared skirt (tanzeb), tall jewelled crown, rifle.
	_humanoid(5.0, 7.2, 5.4, 11.0, 6.8, 5.6, false)
	_cyl(_body, 3.0, 6.9, 11.0, Vector3(0, 5.6, 0), _main, 14)
	_cyl(_body, 6.9, 7.0, 1.0, Vector3(0, 0.6, 0), GOLD, 14, 0.6)
	# Long dark hair
	_box(_head, Vector3(5.6, 6.2, 1.6), Vector3(0, 1.8, -2.6), HAT_BLACK)
	# Crown: band + spikes + central jewel
	_cyl(_head, 2.9, 3.1, 1.6, Vector3(0, 6.6, 0), GOLD, 10, 0.7)
	for i in range(7):
		var a := TAU * float(i) / 7.0
		var spike := _cyl(_head, 0.0, 0.8, 2.6, Vector3(sin(a) * 2.7, 8.6, cos(a) * 2.7), GOLD, 5, 0.7)
		spike.name = "CrownSpike%d" % i
	_sph(_head, 1.0, Vector3(0, 7.2, 3.0), _dark, 1.0, 0.3)
	# Embroidered scarf over shoulders
	_box(_body, Vector3(6.4, 1.0, 4.0), Vector3(0, 11.6, 0), _dark)
	_make_weapon("rifle", Vector3(2.9, 9.8, 2.2))

func _build_king() -> void:
	# Shah: tallest, jewelled Kiani crown with jiqqa feather, beard, cape, sword + pistol.
	_humanoid(6.0, 8.4, 6.6, 4.5, 4.8, 6.4)
	# Cape
	_box(_body, Vector3(7.8, 12.0, 0.9), Vector3(0, 11.0, -3.0), _dark)
	_box(_body, Vector3(8.4, 1.2, 1.2), Vector3(0, 17.2, -2.6), GOLD, 0.6)
	_cyl(_body, 4.0, 5.4, 3.2, Vector3(0, 6.4, 0), _main, 12)
	# Kiani crown: tapered cylinder + arches + feather jiqqa
	_cyl(_head, 3.0, 3.6, 3.6, Vector3(0, 6.8, 0), GOLD, 10, 0.7)
	_cyl(_head, 3.7, 3.7, 0.8, Vector3(0, 5.2, 0), _main, 10)
	_cyl(_head, 1.5, 3.0, 1.8, Vector3(0, 9.4, 0), GOLD, 10, 0.7)
	_sph(_head, 1.1, Vector3(0, 10.8, 0), _dark, 1.0, 0.4)
	_box(_head, Vector3(0.5, 3.2, 1.8), Vector3(0, 8.4, 3.3), GOLD, 0.7)      # jiqqa plume
	_sph(_head, 0.9, Vector3(0, 6.8, 3.4), _main, 1.0, 0.3)
	_pigment_beard(6.6, 3.4)
	_make_weapon("sword", Vector3(3.9, 10.5, 2.6), 1.15)

func _build_knight() -> void:
	# Cavalryman on a horse; rider carries a shamshir.
	_body = _node(self, "Body")
	var coat := _main
	# Horse body
	_box(_body, Vector3(6.6, 7.0, 15.0), Vector3(0, 11.0, 0), Color(0.46, 0.30, 0.18))
	_box(_body, Vector3(7.0, 1.0, 9.0), Vector3(0, 14.9, -0.5), coat)           # saddle cloth
	_box(_body, Vector3(7.2, 0.6, 9.4), Vector3(0, 14.4, -0.5), GOLD, 0.5)
	# Neck + head
	var neck := _node(_body, "Neck", Vector3(0, 13.5, 6.4))
	neck.rotation_degrees.x = 40.0
	_box(neck, Vector3(3.4, 8.0, 3.8), Vector3(0, 3.4, 0), Color(0.46, 0.30, 0.18))
	_box(neck, Vector3(0.9, 7.4, 1.6), Vector3(0, 3.4, -1.9), HAT_BLACK)         # mane
	_head = _node(neck, "Head", Vector3(0, 7.6, 0.6))
	_head.rotation_degrees.x = 50.0
	_box(_head, Vector3(3.2, 6.0, 3.0), Vector3(0, 1.6, 0), Color(0.46, 0.30, 0.18))
	_box(_head, Vector3(3.0, 2.2, 2.8), Vector3(0, -1.0, 0.6), Color(0.34, 0.22, 0.14))   # muzzle
	_box(_head, Vector3(0.9, 1.6, 0.6), Vector3(-1.1, 4.8, -0.4), Color(0.46, 0.30, 0.18))
	_box(_head, Vector3(0.9, 1.6, 0.6), Vector3(1.1, 4.8, -0.4), Color(0.46, 0.30, 0.18))
	_box(_head, Vector3(3.4, 0.7, 3.2), Vector3(0, 3.2, 0.2), _main)             # bridle
	_box(_head, Vector3(0.5, 0.5, 0.5), Vector3(-1.7, 2.6, 0.9), HAT_BLACK)
	_box(_head, Vector3(0.5, 0.5, 0.5), Vector3(1.7, 2.6, 0.9), HAT_BLACK)
	# Tail
	var tail := _node(_body, "Tail", Vector3(0, 13.4, -7.4))
	tail.rotation_degrees.x = -30.0
	_box(tail, Vector3(1.2, 6.0, 1.4), Vector3(0, -2.6, 0), HAT_BLACK)
	# Legs (pivot at the body)
	var lp := [Vector3(-2.4, 8.0, 5.2), Vector3(2.4, 8.0, 5.2), Vector3(-2.4, 8.0, -5.2), Vector3(2.4, 8.0, -5.2)]
	for i in range(4):
		var lg := _node(_body, "HorseLeg%d" % i, lp[i])
		_box(lg, Vector3(1.9, 8.0, 1.9), Vector3(0, -4.0, 0), Color(0.40, 0.26, 0.15))
		_box(lg, Vector3(2.2, 1.2, 2.4), Vector3(0, -8.0, 0.2), BOOT)
		_horse_legs.append(lg)
	# Rider
	var rider := _node(_body, "Rider", Vector3(0, 15.3, -0.5))
	_box(rider, Vector3(4.6, 6.0, 3.0), Vector3(0, 3.0, 0), _main)
	_box(rider, Vector3(4.8, 1.0, 3.2), Vector3(0, 1.4, 0), _dark)
	_box(rider, Vector3(0.6, 4.0, 0.3), Vector3(0, 3.6, 1.6), GOLD, 0.5)
	_head = _node(rider, "RiderHead", Vector3(0, 6.2, 0))
	_sph(_head, 1.8, Vector3(0, 1.4, 0), SKIN)
	_face_small_rider(_head)
	_hat_kolah_rider(_head)
	_arm_r = _node(rider, "RiderArmR", Vector3(2.8, 5.4, 0))
	_box(_arm_r, Vector3(1.3, 4.6, 1.4), Vector3(0, -2.3, 0), _main)
	_arm_l = _node(rider, "RiderArmL", Vector3(-2.8, 5.4, 0))
	_box(_arm_l, Vector3(1.3, 4.6, 1.4), Vector3(0, -2.3, 0), _main)
	_weapon_kind = "sword"
	_weapon = _node(rider, "Weapon", Vector3(3.6, 3.2, 2.4))
	_box(_weapon, Vector3(0.9, 0.9, 2.6), Vector3(0, 0, -1.3), WOOD)
	_box(_weapon, Vector3(0.6, 3.2, 0.8), Vector3(0, 0, 0.0), GOLD, 0.7)
	_box(_weapon, Vector3(0.5, 1.2, 9.0), Vector3(0, 0, 4.6), STEEL, 0.9)
	_hip_y = 8.0

func _hat_kolah_rider(head: Node3D) -> void:
	_cyl(head, 1.9, 1.7, 3.4, Vector3(0, 4.0, 0), HAT_BLACK, 10)
	_cyl(head, 2.0, 2.0, 0.6, Vector3(0, 2.7, 0), _main, 10)

# ── Animations ─────────────────────────────────────────────────────────────
func _path(n: Node) -> String:
	return str(_anim_player.get_parent().get_path_to(n))

func _key(anim: Animation, n: Node, prop: String, keys: Array, discrete: bool = false) -> void:
	if n == null:
		return
	var ti := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ti, NodePath("%s:%s" % [_path(n), prop]))
	if discrete:
		anim.value_track_set_update_mode(ti, Animation.UPDATE_DISCRETE)
	else:
		anim.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
	for k in keys:
		anim.track_insert_key(ti, float(k[0]), k[1])

func _build_animations() -> void:
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	add_child(_anim_player)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _anim_idle())
	lib.add_animation("walk", _anim_walk())
	lib.add_animation("attack", _anim_attack())
	lib.add_animation("death", _anim_death())
	if _kind == ChessEnums.PieceType.KNIGHT:
		lib.add_animation("jump", _anim_jump())
	_anim_player.add_animation_library("", lib)

func _d(deg: float) -> Vector3:
	return Vector3(deg_to_rad(deg), 0, 0)

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.4
	a.loop_mode = Animation.LOOP_PINGPONG
	if _body != null:
		_key(a, _body, "position", [[0.0, Vector3(0, 0, 0)], [1.4, Vector3(0, 0.35, 0)]])
	if _head != null and _kind != ChessEnums.PieceType.KNIGHT:
		_key(a, _head, "rotation", [[0.0, _d(0)], [1.4, _d(-3)]])
	if _weapon != null:
		var rest := _weapon_rest_rot()
		_key(a, _weapon, "rotation", [[0.0, rest], [1.4, rest + _d(-2.5)]])
	_arm_pose(a, 0.0, 1.4, false)
	return a

func _weapon_rest_rot() -> Vector3:
	match _weapon_kind:
		"sword":  return _d(-55) if _kind != ChessEnums.PieceType.KNIGHT else _d(-35)
		"pistol": return _d(-15)
		"staff":  return _d(-80)
		_:        return _d(-55)

func _arm_pose(a: Animation, t0: float, t1: float, aim: bool) -> void:
	if _arm_l == null or _arm_r == null:
		return
	var r_deg := -70.0 if aim else -55.0
	_key(a, _arm_r, "rotation", [[t0, _d(r_deg)], [t1, _d(r_deg)]])
	_key(a, _arm_l, "rotation", [[t0, _d(-35.0 if _weapon_kind != "sword" else 0.0)], [t1, _d(-35.0 if _weapon_kind != "sword" else 0.0)]])

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.8
	a.loop_mode = Animation.LOOP_LINEAR
	if _body != null:
		_key(a, _body, "position", [[0.0, Vector3(0, 0, 0)], [0.2, Vector3(0, 0.9, 0)], [0.4, Vector3(0, 0, 0)], [0.6, Vector3(0, 0.9, 0)], [0.8, Vector3(0, 0, 0)]])
		_key(a, _body, "rotation", [[0.0, Vector3(0, 0.05, 0)], [0.4, Vector3(0, -0.05, 0)], [0.8, Vector3(0, 0.05, 0)]])
	if _kind == ChessEnums.PieceType.KNIGHT:
		# Trot: diagonal leg pairs
		var ph := [0, 1, 1, 0]
		for i in range(_horse_legs.size()):
			var s := 28.0 if ph[i] == 0 else -28.0
			_key(a, _horse_legs[i], "rotation", [[0.0, _d(s)], [0.4, _d(-s)], [0.8, _d(s)]])
	else:
		if _leg_l != null:
			_key(a, _leg_l, "rotation", [[0.0, _d(32)], [0.4, _d(-32)], [0.8, _d(32)]])
			_key(a, _leg_r, "rotation", [[0.0, _d(-32)], [0.4, _d(32)], [0.8, _d(-32)]])
	if _weapon != null:
		var rest := _weapon_rest_rot()
		_key(a, _weapon, "rotation", [[0.0, rest], [0.4, rest + _d(-4)], [0.8, rest]])
	_arm_pose(a, 0.0, 0.8, false)
	return a

func _anim_attack() -> Animation:
	# Timeline matches the scenes' attack_trail_* values: wind-up 0.36, hit 0.66, end 1.07.
	var a := Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_NONE
	var rest := _weapon_rest_rot()
	if _body != null:
		_key(a, _body, "rotation", [[0.0, _d(0)], [0.36, _d(-12)], [0.66, _d(16)], [1.2, _d(0)]])
		_key(a, _body, "position", [[0.0, Vector3.ZERO], [0.36, Vector3(0, 0, -0.8)], [0.66, Vector3(0, 0, 1.8)], [1.2, Vector3.ZERO]])
	if _kind == ChessEnums.PieceType.KNIGHT:
		# Rear up and strike
		_key(a, _body, "rotation", [[0.0, _d(0)], [0.36, _d(-22)], [0.66, _d(8)], [1.2, _d(0)]])
		if _weapon != null:
			_key(a, _weapon, "rotation", [[0.0, rest], [0.36, _d(-120)], [0.66, _d(25)], [1.2, rest]])
		return a
	if _weapon != null:
		match _weapon_kind:
			"sword":
				_key(a, _weapon, "rotation", [[0.0, rest], [0.36, _d(-130)], [0.66, _d(30)], [1.2, rest]])
			"staff":
				_key(a, _weapon, "rotation", [[0.0, rest], [0.36, _d(-120)], [0.66, _d(20)], [1.2, rest]])
			_:
				# Guns: shoulder at 0.36, fire + bayonet thrust at 0.66
				_key(a, _weapon, "rotation", [[0.0, rest], [0.36, _d(-8)], [0.66, _d(-10)], [1.2, rest]])
				var p0 := _weapon.position
				_key(a, _weapon, "position", [[0.0, p0], [0.36, p0 + Vector3(0, 0.6, 0)], [0.60, p0 + Vector3(0, 0.6, 0)], [0.66, p0 + Vector3(0, 0.6, 3.5)], [0.9, p0 + Vector3(0, 0.6, 0)], [1.2, p0]])
				if _flash != null:
					_key(a, _flash, "visible", [[0.0, false], [0.64, true], [0.76, false]], true)
	if _arm_r != null:
		_key(a, _arm_r, "rotation", [[0.0, _d(-55)], [0.36, _d(-95)], [0.66, _d(-75)], [1.2, _d(-55)]])
	if _arm_l != null:
		_key(a, _arm_l, "rotation", [[0.0, _d(-35)], [0.36, _d(-90)], [0.66, _d(-80)], [1.2, _d(-35)]])
	return a

func _anim_death() -> Animation:
	var a := Animation.new()
	var dlen := 1.8
	match _kind:
		ChessEnums.PieceType.ROOK, ChessEnums.PieceType.KING: dlen = 2.4
		ChessEnums.PieceType.QUEEN: dlen = 1.4
	a.length = dlen
	a.loop_mode = Animation.LOOP_NONE
	if _body != null:
		# Stagger, tip backwards and slump to the floor.
		_key(a, _body, "rotation", [[0.0, _d(0)], [dlen * 0.25, _d(10)], [dlen * 0.6, _d(-88)], [dlen, _d(-90)]])
		_key(a, _body, "position", [[0.0, Vector3.ZERO], [dlen * 0.25, Vector3(0, 0, 1.0)], [dlen * 0.6, Vector3(0, 0.0, -3.0)], [dlen, Vector3(0, -1.2, -3.5)]])
	if _arm_l != null:
		_key(a, _arm_l, "rotation", [[0.0, _d(-35)], [dlen * 0.4, _d(-150)], [dlen, _d(-170)]])
	if _arm_r != null:
		_key(a, _arm_r, "rotation", [[0.0, _d(-55)], [dlen * 0.4, _d(-140)], [dlen, _d(-160)]])
	if _weapon != null:
		_key(a, _weapon, "rotation", [[0.0, _weapon_rest_rot()], [dlen * 0.6, _d(60)], [dlen, _d(90)]])
	return a

func _anim_jump() -> Animation:
	# Knight: rear up on take-off, tuck the hooves in the air, extend for landing.
	var a := Animation.new()
	a.length = 1.5
	a.loop_mode = Animation.LOOP_NONE
	_key(a, _body, "rotation", [[0.0, _d(0)], [0.25, _d(-20)], [0.7, _d(-6)], [1.2, _d(10)], [1.5, _d(0)]])
	for i in range(_horse_legs.size()):
		var front := i < 2
		var up := -55.0 if front else 30.0
		var down := 20.0 if front else -25.0
		_key(a, _horse_legs[i], "rotation", [[0.0, _d(0)], [0.3, _d(up)], [0.9, _d(up * 0.6)], [1.3, _d(down)], [1.5, _d(0)]])
	if _weapon != null:
		_key(a, _weapon, "rotation", [[0.0, _weapon_rest_rot()], [0.5, _d(-100)], [1.2, _d(-60)], [1.5, _weapon_rest_rot()]])
	return a

func _count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _count_meshes(ch)
	return c

func _face_small_rider(head: Node3D) -> void:
	# Rider face is tiny; just eyes + a bold curled moustache.
	for sx in [-1.0, 1.0]:
		_box(head, Vector3(0.45, 0.4, 0.3), Vector3(sx * 0.7, 1.8, 1.65), HAT_BLACK)
		var tip := _box(head, Vector3(0.9, 0.3, 0.4), Vector3(sx * 1.0, 1.0, 1.6), HAT_BLACK)
		tip.rotation_degrees.z = sx * 28.0
	_box(head, Vector3(2.0, 0.45, 0.45), Vector3(0, 0.9, 1.65), HAT_BLACK)
	_box(head, Vector3(0.5, 0.8, 0.6), Vector3(0, 1.4, 1.75), Color(0.80, 0.58, 0.43))
