extends Node3D

var kind: int = 0
var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
var cut: bool = false
var fragment: bool = false
var decorative: bool = false
var age: float = 0.0
var radius: float = 0.62
var visual: Node3D
const NAMES = ["apple", "pear", "lemon", "watermelon"]
const HEIGHTS = [0.190753, 0.270753, 0.224, 0.4761]
const SIZES = [0.196295, 0.270753, 0.224, 0.4761]
const COLORS = [Color("ef604f"), Color("b8d967"), Color("ffdf5c"), Color("fb6680")]

func setup(type: int, half: bool = false, second: bool = false) -> void:
	kind = type
	visual = Node3D.new()
	add_child(visual)
	if kind == 4:
		var sphere := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.55
		mesh.height = 1.1
		sphere.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("18222a")
		material.metallic = 0.65
		material.roughness = 0.3
		sphere.material_override = material
		visual.add_child(sphere)
		var fuse := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.06
		cylinder.bottom_radius = 0.08
		cylinder.height = 0.35
		fuse.mesh = cylinder
		fuse.position = Vector3(0.08, 0.65, 0)
		fuse.rotation.z = -0.25
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("ff9f4d")
		glow.emission_enabled = true
		glow.emission = Color("ff4e24")
		glow.emission_energy_multiplier = 2
		fuse.material_override = glow
		visual.add_child(fuse)
		return
	var path: String = "res://assets/models/" + NAMES[kind] + ("-half" if half and kind < 3 else "") + ".glb"
	var model := (load(path) as PackedScene).instantiate() as Node3D
	var scale_factor: float = (1.5 if kind == 3 else 1.25) / SIZES[kind]
	visual.scale = Vector3.ONE * scale_factor
	visual.add_child(model)
	_apply_palette(model, Transform3D.IDENTITY)
	model.position.y = -HEIGHTS[kind] * 0.5
	if half and second:
		if kind == 2:
			model.rotation.z = PI
			model.position.y += HEIGHTS[kind]
		else:
			model.rotation.y = PI
	radius = 0.77 if kind == 3 else 0.64

func step(delta: float) -> void:
	age += delta
	if decorative:
		rotation += spin * delta
		return
	velocity.y -= 8.7 * delta
	position += velocity * delta
	rotation += spin * delta

func juice_color() -> Color:
	return COLORS[kind] if kind < 4 else Color("ff9454")

func _apply_palette(node: Node3D, accumulated: Transform3D) -> void:
	var local_transform: Transform3D = accumulated * node.transform
	if node is MeshInstance3D:
		var material := ShaderMaterial.new()
		material.shader = load("res://scripts/fruit_palette.gdshader")
		material.set_shader_parameter("palette", load("res://assets/models/Textures/colormap.png"))
		material.set_shader_parameter("fruit_kind", kind)
		material.set_shader_parameter("model_from_mesh", local_transform)
		node.material_override = material
	for child in node.get_children():
		if child is Node3D:
			_apply_palette(child, local_transform)
