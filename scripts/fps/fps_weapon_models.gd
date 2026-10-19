## fps_weapon_models.gd
## Placeholder gun models built from primitive meshes (no external assets).
## Every model points down -Z and has a Marker3D called "Muzzle" at the barrel tip.
##
## To use real models later: put a .glb/.tscn at res://assets/models/guns/<kind>.tscn
## (barrel along -Z, with a Marker3D named "Muzzle") and it is picked up automatically.

class_name FpsWeaponModels
extends RefCounted

const METAL := Color(0.10, 0.10, 0.11)
const METAL_LIGHT := Color(0.28, 0.28, 0.30)
const WOOD := Color(0.36, 0.20, 0.09)
const POLYMER := Color(0.06, 0.06, 0.07)

static func build(kind: String) -> Node3D:
	var custom_path := "res://assets/models/guns/%s.tscn" % kind
	if ResourceLoader.exists(custom_path):
		var scene := load(custom_path) as PackedScene
		if scene != null:
			var inst := scene.instantiate() as Node3D
			if inst != null:
				return inst
	var root := Node3D.new()
	root.name = "GunModel"
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	root.add_child(muzzle)
	match kind:
		"pistol":
			_box(root, Vector3(0.034, 0.04, 0.20), Vector3(0, 0.0, -0.10), METAL_LIGHT)
			_box(root, Vector3(0.030, 0.10, 0.045), Vector3(0, -0.065, -0.02), WOOD, Vector3(-12, 0, 0))
			_box(root, Vector3(0.026, 0.03, 0.10), Vector3(0, -0.032, -0.09), METAL)
			muzzle.position = Vector3(0, 0.005, -0.205)
		"deagle":
			_box(root, Vector3(0.04, 0.052, 0.26), Vector3(0, 0.0, -0.13), METAL_LIGHT)
			_box(root, Vector3(0.036, 0.115, 0.055), Vector3(0, -0.08, -0.02), POLYMER, Vector3(-12, 0, 0))
			_box(root, Vector3(0.03, 0.034, 0.12), Vector3(0, -0.04, -0.11), METAL)
			muzzle.position = Vector3(0, 0.008, -0.265)
		"smg":
			_box(root, Vector3(0.045, 0.065, 0.24), Vector3(0, 0, -0.12), METAL)
			_box(root, Vector3(0.028, 0.17, 0.036), Vector3(0, -0.115, -0.03), METAL_LIGHT)
			_box(root, Vector3(0.034, 0.08, 0.04), Vector3(0, -0.07, 0.04), POLYMER, Vector3(-15, 0, 0))
			_cyl(root, 0.011, 0.12, Vector3(0, 0.012, -0.30), METAL_LIGHT)
			_box(root, Vector3(0.02, 0.02, 0.16), Vector3(0, 0.0, 0.16), METAL_LIGHT)
			muzzle.position = Vector3(0, 0.012, -0.36)
		"shotgun":
			_cyl(root, 0.014, 0.72, Vector3(0, 0.02, -0.36), METAL)
			_cyl(root, 0.012, 0.50, Vector3(0, -0.012, -0.28), METAL_LIGHT)
			_box(root, Vector3(0.034, 0.05, 0.16), Vector3(0, -0.005, -0.40), WOOD)
			_box(root, Vector3(0.04, 0.075, 0.20), Vector3(0, 0.0, 0.0), METAL)
			_box(root, Vector3(0.036, 0.09, 0.30), Vector3(0, -0.03, 0.22), WOOD, Vector3(8, 0, 0))
			muzzle.position = Vector3(0, 0.02, -0.73)
		"g3":
			_box(root, Vector3(0.042, 0.07, 0.38), Vector3(0, 0, -0.10), METAL)
			_box(root, Vector3(0.046, 0.05, 0.26), Vector3(0, -0.005, -0.40), POLYMER)
			_cyl(root, 0.011, 0.16, Vector3(0, 0.014, -0.60), METAL_LIGHT)
			_box(root, Vector3(0.03, 0.15, 0.05), Vector3(0, -0.11, -0.06), METAL_LIGHT, Vector3(12, 0, 0))
			_box(root, Vector3(0.034, 0.075, 0.045), Vector3(0, -0.07, 0.05), POLYMER, Vector3(-14, 0, 0))
			_box(root, Vector3(0.04, 0.09, 0.30), Vector3(0, -0.02, 0.32), POLYMER, Vector3(6, 0, 0))
			muzzle.position = Vector3(0, 0.014, -0.69)
		"ak":
			_box(root, Vector3(0.04, 0.065, 0.36), Vector3(0, 0, -0.08), METAL)
			_box(root, Vector3(0.044, 0.045, 0.24), Vector3(0, -0.012, -0.36), WOOD)
			_cyl(root, 0.011, 0.20, Vector3(0, 0.02, -0.56), METAL_LIGHT)
			_box(root, Vector3(0.03, 0.17, 0.05), Vector3(0, -0.12, -0.10), METAL_LIGHT, Vector3(18, 0, 0))
			_box(root, Vector3(0.034, 0.08, 0.045), Vector3(0, -0.07, 0.06), WOOD, Vector3(-14, 0, 0))
			_box(root, Vector3(0.038, 0.10, 0.30), Vector3(0, -0.025, 0.30), WOOD, Vector3(10, 0, 0))
			muzzle.position = Vector3(0, 0.02, -0.67)
		_:
			_box(root, Vector3(0.04, 0.05, 0.25), Vector3(0, 0, -0.12), METAL)
			muzzle.position = Vector3(0, 0, -0.25)
	return root

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.5
	m.roughness = 0.55
	return m

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Cylinder lying along the Z axis.
static func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3,
		color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
