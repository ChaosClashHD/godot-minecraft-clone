extends CharacterBody3D

@export var walk_speed: float = 5.5
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 7.5
@export var gravity: float = 22.0
@export var mouse_sensitivity: float = 0.0025

var world: Node3D
var target_block: Vector3i
var target_normal: Vector3i = Vector3i.ZERO
var head: Node3D
var camera: Camera3D
var grounded: bool = false

func _ready() -> void:
	call_deferred("_bind_world")
	_setup_input()
	head = $Head
	camera = $Head/Camera3D
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _bind_world() -> void:
	world = get_parent().get_node("World")

func _setup_input() -> void:
	var actions: Array[String] = [
		"move_forward", "move_back", "move_left", "move_right", "jump", "sprint",
		"break_block", "place_block"
	]

	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	var key_map: Dictionary = {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
	}

	for action in key_map.keys():
		for key in key_map[action]:
			if key is String:
				continue
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("break_block", left_click)

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("place_block", right_click)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		head.rotation.x -= event.relative.y * mouse_sensitivity
		head.rotation.x = clamp(head.rotation.x, -1.55, 1.55)

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_break_target_block()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_place_target_block()

func _physics_process(delta: float) -> void:
	if world == null:
		return

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction: Vector3 = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()

	var desired_speed: float = walk_speed
	if Input.is_action_pressed("sprint"):
		desired_speed = sprint_speed

	velocity.x = move_direction.x * desired_speed
	velocity.z = move_direction.z * desired_speed

	if grounded and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		grounded = false
	else:
		velocity.y -= gravity * delta

	var surface_y: float = float(world.get_surface_height(global_position.x, global_position.z)) + 1.7
	if global_position.y < surface_y and velocity.y <= 0.0:
		global_position.y = surface_y
		velocity.y = 0.0
		grounded = true
	else:
		grounded = false

	move_and_slide()

	var terrain_height: float = world.get_surface_height(global_position.x, global_position.z)
	if global_position.y < terrain_height + 1.7:
		global_position.y = terrain_height + 1.7
		velocity.y = 0.0
		grounded = true

	_update_target_block()

func _update_target_block() -> void:
	if world == null:
		return

	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var target: Vector3 = origin + forward * 7.0
	var hit: Dictionary = world.raycast(origin, target, 7.0)
	if hit.is_empty():
		target_block = Vector3i.ZERO
		target_normal = Vector3i.ZERO
		return

	target_block = hit["cell"]
	target_normal = hit["normal"]

func _break_target_block() -> void:
	if world == null:
		return

	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var hit: Dictionary = world.raycast(origin, origin + forward * 7.0, 7.0)
	if hit.is_empty():
		return

	var cell: Vector3i = hit["cell"] as Vector3i
	world.remove_block(cell)

func _place_target_block() -> void:
	if world == null:
		return

	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var hit: Dictionary = world.raycast(origin, origin + forward * 7.0, 7.0)
	if hit.is_empty():
		return

	var cell: Vector3i = hit["cell"] as Vector3i
	var normal: Vector3i = hit["normal"] as Vector3i
	var place_cell: Vector3i = cell + normal

	if place_cell.distance_to(global_position) < 1.3:
		return

	world.set_block(place_cell, "dirt")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_break_target_block()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_place_target_block()
