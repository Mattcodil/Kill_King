## qajar_menu_theme.gd
## Re-skins the main menu as "شاه‌کُش" (Shah-Kosh) with a Qajar look:
## tiled turquoise/gold star pattern, Persian title + buttons, an ornamental
## pointed arch (ayvan) with the two kings of the Turquoise and Lacquer armies.
## Everything is built in code on top of the existing menu scene.
## Call QajarMenuTheme.apply(menu) from main_menu.gd _ready().

class_name QajarMenuTheme
extends RefCounted

const GAME_NAME := "شاه‌کُش"
const FONT_BOLD_PATH := "res://assets/fonts/Vazirmatn-Bold.ttf"
const FONT_REG_PATH  := "res://assets/fonts/Vazirmatn-Regular.ttf"
const BG_PATH        := "res://assets/textures/qajar/qajar_bg.png"

const GOLD       := Color(0.98, 0.80, 0.30)
const GOLD_DARK  := Color(0.62, 0.45, 0.12)
const TURQ       := Color(0.10, 0.66, 0.70)
const TURQ_DEEP  := Color(0.03, 0.22, 0.26)

# Persian labels keyed by the existing button node names.
const BUTTON_TEXT := {
	"PvPBtn":       "  دو نفره",
	"PvAIBtn":      "  مقابل رایانه",
	"OnlineBtn":    "  برخط",
	"StatsBtn":     "  آمار",
	"SettingsBtn":  "  تنظیمات",
	"QuitBtn":      "  خروج",
}

static func apply(menu: Control) -> void:
	DisplayServer.window_set_title(GAME_NAME)
	var bold := _load_font(FONT_BOLD_PATH)
	var reg  := _load_font(FONT_REG_PATH)
	_restyle_background(menu)
	_restyle_title(menu, bold)
	_restyle_buttons(menu, bold)
	_restyle_credit(menu, reg)
	_add_arch_with_kings(menu)

static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null

static func _restyle_background(menu: Control) -> void:
	var bg := menu.get_node_or_null("Bg") as TextureRect
	if bg != null and ResourceLoader.exists(BG_PATH):
		bg.texture = load(BG_PATH) as Texture2D
	var circuit := menu.get_node_or_null("Circuit") as CanvasItem
	if circuit != null:
		circuit.visible = false
	# Dark turquoise vignette-free base behind everything (in case the pattern has gaps)
	var base := ColorRect.new()
	base.name = "QajarBase"
	base.color = TURQ_DEEP
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.z_index = -2
	menu.add_child(base)
	menu.move_child(base, 0)

static func _restyle_title(menu: Control, bold: Font) -> void:
	var title := menu.get_node_or_null("Title") as Label
	if title == null:
		return
	title.text = GAME_NAME
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.10))
	title.add_theme_constant_override("outline_size", 14)
	if bold != null:
		title.add_theme_font_override("font", bold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

static func _restyle_buttons(menu: Control, bold: Font) -> void:
	for node_name in BUTTON_TEXT:
		var b := menu.find_child(node_name, true, false) as Button
		if b == null:
			continue
		b.text = BUTTON_TEXT[node_name]
		if bold != null:
			b.add_theme_font_override("font", bold)
		b.add_theme_font_size_override("font_size", 38)
		b.add_theme_constant_override("outline_size", 8)

static func _restyle_credit(menu: Control, reg: Font) -> void:
	var lbl := menu.get_node_or_null("Version") as Label
	if lbl == null:
		return
	var v := str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	# Keep the original attribution (CC BY-NC-SA 4.0 requires it).
	lbl.text = "شاه‌کُش — برگرفته از Duke's Gambit اثر 0xMartin (CC BY-NC-SA 4.0)  |  v%s" % v
	lbl.add_theme_color_override("font_color", Color(0.86, 0.74, 0.42))
	if reg != null:
		lbl.add_theme_font_override("font", reg)

# ── Arch with a gold chess-king silhouette (left side of the menu) ───────
static func _add_arch_with_kings(menu: Control) -> void:
	var old := menu.get_node_or_null("DukeIcon") as CanvasItem
	if old != null:
		old.visible = false
	var holder := Control.new()
	holder.name = "QajarArch"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.anchor_right = 0.4659584
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.z_index = -1   # stay behind labels (credit line) and buttons
	menu.add_child(holder)
	var arch := _ArchDrawing.new()
	arch.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(arch)


## Pointed arch (ayvan): thin double gold outline over a dark translucent field.
class _ArchDrawing extends Control:
	func _arch_points(scale_f: float) -> PackedVector2Array:
		var cx := size.x * 0.5
		var half := minf(size.x * 0.40, size.y * 0.32) * scale_f
		var base_y := size.y * 0.90
		var spring_y := size.y * 0.42
		var apex_y := size.y * 0.10
		var centre_y := (apex_y + base_y) * 0.5
		var pts := PackedVector2Array()
		pts.append(Vector2(cx - half, base_y))
		pts.append(Vector2(cx - half, spring_y))
		for i in range(1, 25):
			var t := float(i) / 24.0
			pts.append(Vector2(lerpf(cx - half, cx, t), spring_y - (spring_y - apex_y) * sin(t * PI * 0.5) * (1.0 - 0.25 * t)))
		for i in range(23, -1, -1):
			var t2 := float(i) / 24.0
			pts.append(Vector2(lerpf(cx + half, cx, t2), spring_y - (spring_y - apex_y) * sin(t2 * PI * 0.5) * (1.0 - 0.25 * t2)))
		pts.append(Vector2(cx + half, spring_y))
		pts.append(Vector2(cx + half, base_y))
		return pts


	## Concentric eight-point star medallion (shamseh) in thin gold lines.
	func _draw_rosette() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.54)
		var r0 := minf(size.x * 0.30, size.y * 0.24)
		var gold := Color(0.80, 0.63, 0.24, 0.95)
		for layer in range(4):
			var r := r0 * (1.0 - 0.22 * float(layer))
			var pts := PackedVector2Array()
			var rot := 0.0 if layer % 2 == 0 else PI / 8.0
			for k in range(16):
				var a := rot + TAU * float(k) / 16.0
				var rr := r if k % 2 == 0 else r * 0.62
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			pts.append(pts[0])
			draw_polyline(pts, Color(gold.r, gold.g, gold.b, 0.95 - 0.15 * float(layer)), 1.8 - 0.2 * float(layer), true)
		draw_circle(c, r0 * 0.07, Color(0.80, 0.63, 0.24, 0.9))
		draw_arc(c, r0 * 1.12, 0.0, TAU, 64, Color(gold.r, gold.g, gold.b, 0.5), 1.2, true)

	func _draw() -> void:
		if size.x < 10.0 or size.y < 10.0:
			return
		var outer := _arch_points(1.0)
		draw_colored_polygon(outer, Color(0.0, 0.07, 0.09, 0.55))
		var gold := Color(0.80, 0.63, 0.24, 0.95)
		draw_polyline(outer, gold, 2.5, true)
		var inner := _arch_points(0.93)
		draw_polyline(inner, Color(0.80, 0.63, 0.24, 0.55), 1.2, true)
		# Small eight-point star at the apex
		var c := Vector2(size.x * 0.5, size.y * 0.19)
		var r := size.x * 0.03
		var star := PackedVector2Array()
		for k in range(16):
			var a := TAU * float(k) / 16.0
			var rr := r if k % 2 == 0 else r * 0.5
			star.append(c + Vector2(cos(a), sin(a)) * rr)
		star.append(star[0])
		draw_polyline(star, gold, 1.6, true)
		_draw_rosette()
		# Base line
		var cx := size.x * 0.5
		var half := minf(size.x * 0.40, size.y * 0.32)
		draw_line(Vector2(cx - half * 1.12, size.y * 0.90), Vector2(cx + half * 1.12, size.y * 0.90), gold, 2.5)
