extends Node3D
class_name VoxelWorld

const BLOCK_COLORS := {
	"grass": Color(0.36, 0.75, 0.26),
	"dirt": Color(0.54, 0.33, 0.20),
	"stone": Color(0.55, 0.55, 0.60),
	"sand": Color(0.86, 0.81, 0.53),
	"wood": Color(0.62, 0.42, 0.24),
	"leaf": Color(0.28, 0.63, 0.28),
	"glass": Color(0.70, 0.90, 1.00, 0.60),
}

const FACE_DEFS := [
	{"normal": Vector3(0, 1, 0), "verts": [Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)]},
	{"normal": Vector3(0, -1, 0), "verts": [Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, -0.5)]},
	{"normal": Vector3(1, 0, 0), "verts": [Vector3(0.5, -0.5, -0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(0.5, 0.5, -0.5)]},
	{"normal": Vector3(-1, 0, 0), "verts": [Vector3(-0.5, -0.5, 0.5), Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, 0.5, -0.5), Vector3(-0.5, 0.5, 0.5)]},
	{"normal": Vector3(0, 0, 1), "verts": [Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)]},
	{"normal": Vector3(0, 0, -1), "verts": [Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5)]},
]

var blocks: Dictionary = {}
var mesh_instance: MeshInstance3D
var world_radius := 12

func _ready() -> void:
	generate_world()

func generate_world() -> void:
	blocks.clear()

	for x in range(-world_radius, world_radius + 1):
		for z in range(-world_radius, world_radius + 1):
			var height := int(round(sin(x * 0.8) * 1.8 + cos(z * 0.75) * 2.0 + 4.0))
			if height < 1:
				height = 1

			for y in range(-1, height + 1):
				var type := "stone"
				if y == height:
					type = "grass"
				elif y >= height - 2:
					type = "dirt"
				blocks[Vector3i(x, y, z)] = type

			if (x + z) % 9 == 0 and abs(x) > 2 and abs(z) > 2:
				place_tree(Vector3i(x, height + 1, z))

	rebuild_mesh()

func place_tree(base: Vector3i) -> void:
	for y in range(0, 4):
		blocks[Vector3i(base.x, base.y + y, base.z)] = "wood"

	for dx in range(-2, 3):
		for dy in range(2, 5):
			for dz in range(-2, 3):
				if abs(dx) + abs(dz) >= 4 and dy < 4:
					continue
				blocks[Vector3i(base.x + dx, base.y + dy, base.z + dz)] = "leaf"

func rebuild_mesh() -> void:
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for block_pos: Vector3i in blocks.keys():
		var type: String = String(blocks[block_pos])
		var color: Color = BLOCK_COLORS.get(type, Color.WHITE)

		for face in FACE_DEFS:
			var neighbor_pos: Vector3i = block_pos + Vector3i(face["normal"])
			if blocks.has(neighbor_pos):
				continue

			var local_vertices: Array[Vector3] = []
			for vertex in face["verts"]:
				local_vertices.append(vertex + Vector3(block_pos))

			for i in range(0, 4):
				var idx_a: int = i
				var idx_b: int = (i + 1) % 4
				var idx_c: int = (i + 2) % 4

				var v0: Vector3 = local_vertices[idx_a]
				var v1: Vector3 = local_vertices[idx_b]
				var v2: Vector3 = local_vertices[idx_c]

				surface_tool.set_color(color)
				surface_tool.add_vertex(v0)
				surface_tool.add_vertex(v1)
				surface_tool.add_vertex(v2)

			for i in range(0, 4):
				var idx_a: int = i
				var idx_b: int = (i + 2) % 4
				var idx_c: int = (i + 3) % 4

				var v0: Vector3 = local_vertices[idx_a]
				var v1: Vector3 = local_vertices[idx_b]
				var v2: Vector3 = local_vertices[idx_c]

				surface_tool.set_color(color)
				surface_tool.add_vertex(v0)
				surface_tool.add_vertex(v1)
				surface_tool.add_vertex(v2)

	surface_tool.generate_normals()
	surface_tool.index()
	mesh_instance.mesh = surface_tool.commit()

func set_block(cell: Vector3i, type: String) -> void:
	blocks[cell] = type
	rebuild_mesh()

func remove_block(cell: Vector3i) -> void:
	if blocks.has(cell):
		blocks.erase(cell)
		rebuild_mesh()

func raycast(origin: Vector3, target: Vector3, max_distance: float = 7.0) -> Dictionary:
	var direction: Vector3 = (target - origin).normalized()
	var distance: float = 0.0
	var previous_cell: Vector3i = Vector3i.ZERO

	while distance <= max_distance:
		var current_point: Vector3 = origin + direction * distance
		var cell: Vector3i = Vector3i(floor(current_point.x), floor(current_point.y), floor(current_point.z))

		if cell != previous_cell and blocks.has(cell):
			return {
				"cell": cell,
				"normal": previous_cell - cell,
				"point": current_point,
			}

		previous_cell = cell
		distance += 0.05

	return {}

func get_surface_height(x: float, z: float) -> float:
	var px: int = int(floor(x))
	var pz: int = int(floor(z))
	var highest: float = -999.0

	for block_pos: Vector3i in blocks.keys():
		if block_pos.x == px and block_pos.z == pz and block_pos.y > highest:
			highest = float(block_pos.y)

	return highest

func is_block_at(cell: Vector3i) -> bool:
	return blocks.has(cell)
