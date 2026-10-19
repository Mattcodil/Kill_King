## fps_fx.gd
## Small static helpers shared by the player and the enemy: aim spread,
## tracers, impact sparks and one-shot sounds.

class_name FpsFx
extends RefCounted

## World scale of the current duel: 1.0 in the stand-alone arena (metres), 0.5 when the
## duel is fought on the chess board itself (pieces are about half human size).
static var unit: float = 1.0

## Random direction inside a cone of `half_angle_deg` around `dir`.
static func cone_dir(dir: Vector3, half_angle_deg: float) -> Vector3:
	var b := dir.normalized()
	if half_angle_deg <= 0.0:
		return b
	var r := tan(deg_to_rad(half_angle_deg)) * sqrt(randf())
	var th := randf() * TAU
	var up := Vector3.UP
	if absf(b.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var right := b.cross(up).normalized()
	var u := right.cross(b).normalized()
	return (b + right * (cos(th) * r) + u * (sin(th) * r)).normalized()

## Damage multiplier by distance: full inside `range_eff`, fading to 35% at 2x.
static func falloff(dist: float, range_eff: float) -> float:
	if range_eff <= 0.0:
		return 1.0
	return clampf(1.0 - (dist - range_eff) / range_eff, 0.35, 1.0)

static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color = Color(1.0, 0.85, 0.4)) -> void:
	var dist := from.distance_to(to)
	if dist < 0.1 or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.006 * unit
	mesh.bottom_radius = 0.006 * unit
	mesh.height = dist
	mesh.radial_segments = 4
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# Cylinder axis is Y: place at the midpoint and rotate Y onto the shot direction.
	var dir := (to - from).normalized()
	var mid := (from + to) * 0.5
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var x := up.cross(dir).normalized()
	var z := x.cross(dir).normalized()
	mi.global_transform = Transform3D(Basis(x, dir, z), mid)
	var timer := parent.get_tree().create_timer(0.05)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free())

static func impact(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.8, 0.4)) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.07 * unit
	mesh.height = 0.14 * unit
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ZERO, 0.18)
	tw.tween_callback(mi.queue_free)

## Fire-and-forget sound. Pass `pos` for positional 3D audio, otherwise it is 2D.
static func play(parent: Node, stream: AudioStream, volume_db: float = 0.0,
		pos: Variant = null) -> void:
	if stream == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if pos is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = volume_db
		p3.unit_size = 10.0 * unit
		p3.bus = "SFX"
		parent.add_child(p3)
		p3.global_position = pos
		p3.finished.connect(p3.queue_free)
		p3.play()
	else:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = volume_db
		p.bus = "SFX"
		parent.add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
