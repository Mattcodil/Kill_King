## board.gd
## Manages the visual 8x8 chessboard and tile highlighting.
## Each tile is a MeshInstance3D. Highlight overlays are separate
## transparent quads rendered just above the board surface.

class_name Board
extends Node3D

# ── Colours (easily tweakable) ────────────────────────────────────────────
# Qajar palette: cream (marble) and turquoise (فیروزه) squares, walnut + gold frame.
const TILE_WHITE     := Color(0.93, 0.87, 0.72)
const TILE_BLACK     := Color(0.05, 0.42, 0.47)
const FRAME_WOOD     := Color(0.24, 0.11, 0.06)
const FRAME_GOLD     := Color(0.93, 0.74, 0.22)
const FRAME_BAND     := Color(0.07, 0.30, 0.34)
const HL_SELECT      := Color(0.00, 1.00, 0.15, 0.95)  # selected piece  – vivid green
const HL_MOVE        := Color(0.10, 0.90, 0.15, 0.80)  # valid move       – green
const HL_CAPTURE     := Color(1.00, 0.05, 0.00, 0.95)  # capture target   – vivid red
const HL_CHECK       := Color(1.00, 0.10, 0.05, 0.95)  # king in check    – vivid red
const HL_LAST_MOVE   := Color(0.90, 0.75, 0.10, 0.55)  # last move        – subtle gold

const TILE_SIZE      := 1.0   # world-units per square
const BLINK_SPEED    := 3.0   # radians/sec for sin() blink
const TILE_HEIGHT    := 0.10  # thickness of board tiles (2x); top stays at Y=0, extends downward
const OVERLAY_OFFSET := 0.001 # tiny Y above tile surface

# ── Internal state ────────────────────────────────────────────────────────
var _tiles: Array = []         # [col][row] -> MeshInstance3D
var _overlays: Array = []      # [col][row] -> MeshInstance3D (highlight quad)
var _overlay_state: Array = [] # [col][row] -> { active, color, blink }
var _time: float = 0.0
var _last_move_from: Vector2i = Vector2i(-1, -1)
var _last_move_to:   Vector2i = Vector2i(-1, -1)
# Shared highlight shader (loaded once, reused for all overlay materials)
var _hl_shader: Shader = null
# ── Initialisation ────────────────────────────────────────────────────────
func _ready() -> void:
	_build_board()

func _build_board() -> void:
	var tile_mesh  := BoxMesh.new()
	tile_mesh.size = Vector3(TILE_SIZE, TILE_HEIGHT, TILE_SIZE)
	var white_tile_mat := StandardMaterial3D.new()
	white_tile_mat.albedo_color = TILE_WHITE
	var black_tile_mat := StandardMaterial3D.new()
	black_tile_mat.albedo_color = TILE_BLACK

	var quad_mesh := PlaneMesh.new()
	quad_mesh.size = Vector2(TILE_SIZE, TILE_SIZE)

	_hl_shader = load("res://shaders/tile_highlight.gdshader") as Shader

	for c in range(8):
		_tiles.append([])
		_overlays.append([])
		_overlay_state.append([])
		for r in range(8):
			# --- tile ---
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			tile.material_override = white_tile_mat if (c + r) % 2 == 0 else black_tile_mat
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tile.position = _sq_to_world(Vector2i(c, r)) + Vector3(0, -TILE_HEIGHT * 0.5, 0)
			add_child(tile)
			_tiles[c].append(tile)

			# --- highlight overlay (ShaderMaterial) ---
			var ov_mat := ShaderMaterial.new()
			ov_mat.shader = _hl_shader
			ov_mat.set_shader_parameter("tile_color", Color(0, 0, 0, 0))

			var ov := MeshInstance3D.new()
			ov.mesh = quad_mesh
			ov.material_override = ov_mat
			ov.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ov.position = _sq_to_world(Vector2i(c, r)) + Vector3(0, OVERLAY_OFFSET, 0)
			ov.visible = false
			add_child(ov)
			_overlays[c].append(ov)
			_overlay_state[c].append({ "active": false, "color": Color.TRANSPARENT, "blink": true })
	_build_frame()


# ── Qajar frame (khatam-style inlay border) ───────────────────────────────
func _frame_mat(c: Color, metallic: float = 0.0, rough: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m

func _frame_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## Decorative border: a flat turquoise band (below the coordinate labels, which lie at y = -0.1),
## a raised walnut rim with gold inlay lines, and gold corner studs.
func _build_frame() -> void:
	var wood := _frame_mat(FRAME_WOOD, 0.0, 0.55)
	var gold := _frame_mat(FRAME_GOLD, 0.3, 0.4)
	var band := _frame_mat(FRAME_BAND, 0.0, 0.6)
	var inner := 4.0                     # board half-width
	var band_w := 0.62                   # flat band that carries the a-h / 1-8 labels
	var rim_w := 0.55
	var mid := inner + band_w * 0.5
	var long_band := (inner + band_w) * 2.0
	var band_y := -TILE_HEIGHT - 0.004
	# Flat band (4 sides)
	_frame_box(Vector3(long_band, 0.01, band_w), Vector3(0, band_y, -mid), band)
	_frame_box(Vector3(long_band, 0.01, band_w), Vector3(0, band_y, mid), band)
	_frame_box(Vector3(band_w, 0.01, inner * 2.0), Vector3(-mid, band_y, 0), band)
	_frame_box(Vector3(band_w, 0.01, inner * 2.0), Vector3(mid, band_y, 0), band)
	# Thin gold line between tiles and band
	var gl := inner + 0.02
	_frame_box(Vector3(inner * 2.0 + 0.08, 0.012, 0.04), Vector3(0, band_y + 0.002, -gl), gold)
	_frame_box(Vector3(inner * 2.0 + 0.08, 0.012, 0.04), Vector3(0, band_y + 0.002, gl), gold)
	_frame_box(Vector3(0.04, 0.012, inner * 2.0), Vector3(-gl, band_y + 0.002, 0), gold)
	_frame_box(Vector3(0.04, 0.012, inner * 2.0), Vector3(gl, band_y + 0.002, 0), gold)
	# Raised walnut rim
	var ro := inner + band_w                # rim inner edge
	var rim_mid := ro + rim_w * 0.5
	var rim_len := (ro + rim_w) * 2.0
	var rim_h := 0.16
	var rim_y := -TILE_HEIGHT + rim_h * 0.5 - 0.004
	_frame_box(Vector3(rim_len, rim_h, rim_w), Vector3(0, rim_y, -rim_mid), wood)
	_frame_box(Vector3(rim_len, rim_h, rim_w), Vector3(0, rim_y, rim_mid), wood)
	_frame_box(Vector3(rim_w, rim_h, ro * 2.0), Vector3(-rim_mid, rim_y, 0), wood)
	_frame_box(Vector3(rim_w, rim_h, ro * 2.0), Vector3(rim_mid, rim_y, 0), wood)
	# Gold inlay on the rim top (two thin lines per side)
	var top_y := rim_y + rim_h * 0.5 + 0.001
	for off in [0.12, rim_w - 0.12]:
		var d: float = ro + off
		var l: float = (d) * 2.0
		_frame_box(Vector3(l, 0.006, 0.03), Vector3(0, top_y, -d), gold)
		_frame_box(Vector3(l, 0.006, 0.03), Vector3(0, top_y, d), gold)
		_frame_box(Vector3(0.03, 0.006, l), Vector3(-d, top_y, 0), gold)
		_frame_box(Vector3(0.03, 0.006, l), Vector3(d, top_y, 0), gold)
	# Gold corner studs
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_frame_box(Vector3(0.34, 0.2, 0.34), Vector3(sx * rim_mid, rim_y + 0.02, sz * rim_mid), gold)
	# Gold mid-side medallions on the band (tiny diamonds), purely decorative
	for i in range(8):
		var t := (float(i) - 3.5) * TILE_SIZE
		for side in [-1.0, 1.0]:
			var dia := _frame_mat(FRAME_GOLD, 0.3, 0.4)
			var dm := _frame_box(Vector3(0.07, 0.012, 0.07), Vector3(t, band_y + 0.004, side * mid), dia)
			dm.rotation_degrees.y = 45.0

# ── Public API ────────────────────────────────────────────────────────────
func clear_highlights() -> void:
	for c in range(8):
		for r in range(8):
			_set_overlay(Vector2i(c, r), Color.TRANSPARENT, false, false)
	# Re-apply last-move highlight so it persists across turns
	if _last_move_from.x >= 0:
		_set_overlay(_last_move_from, HL_LAST_MOVE, true, false)
	if _last_move_to.x >= 0:
		_set_overlay(_last_move_to,   HL_LAST_MOVE, true, false)

func highlight_selected(sq: Vector2i) -> void:
	_set_overlay(sq, HL_SELECT, true, true)

func highlight_moves(moves: Array) -> void:
	for mv in moves:
		if mv.is_capture():
			_set_overlay(mv.to_sq, HL_CAPTURE, true, true)
		else:
			_set_overlay(mv.to_sq, HL_MOVE, true, true)

func highlight_check(sq: Vector2i) -> void:
	_set_overlay(sq, HL_CHECK, true, true)

## Highlight the two squares of the last move (non-blinking gold).
func highlight_last_move(from_sq: Vector2i, to_sq: Vector2i) -> void:
	_last_move_from = from_sq
	_last_move_to   = to_sq
	_set_overlay(from_sq, HL_LAST_MOVE, true, false)
	_set_overlay(to_sq,   HL_LAST_MOVE, true, false)

func clear_last_move() -> void:
	if _last_move_from.x >= 0:
		_set_overlay(_last_move_from, Color.TRANSPARENT, false, false)
	if _last_move_to.x >= 0:
		_set_overlay(_last_move_to,   Color.TRANSPARENT, false, false)
	_last_move_from = Vector2i(-1, -1)
	_last_move_to   = Vector2i(-1, -1)

## World position of the centre of a square (Y = 0 = top of board surface)
func sq_to_world(sq: Vector2i) -> Vector3:
	return _sq_to_world(sq)

## Convert a world XZ position to board square (returns (-1,-1) if off-board)
func world_to_sq(world_pos: Vector3) -> Vector2i:
	var c := int(floor(world_pos.x / TILE_SIZE + 4.0))
	var r := int(floor(world_pos.z / TILE_SIZE + 4.0))
	if c < 0 or c > 7 or r < 0 or r > 7:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

## Centre of the entire board in world space
func board_center() -> Vector3:
	return Vector3(0, 0, 0)

# ── Internal ──────────────────────────────────────────────────────────────
func _sq_to_world(sq: Vector2i) -> Vector3:
	# Centre board at origin: columns a..h → x = -3.5..3.5
	return Vector3((sq.x - 3.5) * TILE_SIZE, 0.0, (sq.y - 3.5) * TILE_SIZE)

func _set_overlay(sq: Vector2i, color: Color, active: bool, blink: bool) -> void:
	var state: Dictionary = _overlay_state[sq.x][sq.y]
	state["active"] = active
	state["color"]  = color
	state["blink"]  = blink
	var ov: MeshInstance3D = _overlays[sq.x][sq.y]
	ov.visible = active
	if active:
		(ov.material_override as ShaderMaterial).set_shader_parameter("tile_color", color)

func _process(delta: float) -> void:
	_time += delta
	var alpha_mod := (sin(_time * BLINK_SPEED) * 0.5 + 0.5)  # 0..1
	for c in range(8):
		for r in range(8):
			var state: Dictionary = _overlay_state[c][r]
			if not state["active"] or not state["blink"]:
				continue
			var base_color: Color = state["color"]
			var blinked := Color(base_color.r, base_color.g, base_color.b,
								 base_color.a * (0.4 + 0.6 * alpha_mod))
			(_overlays[c][r].material_override as ShaderMaterial).set_shader_parameter("tile_color", blinked)
