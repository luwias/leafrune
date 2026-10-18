extends CharacterBody3D
## A tanonc: mozgás, követő kamera, és a legközelebbi dolog kiválasztása, amit használni lehet.

const WALK := 3.0
const RUN := 5.2
const REACH := 1.5
const MOUSE_SENS := 0.0035

var pid := 1
var hud: Node = null

var cam_yaw := 0.0
var cam_pitch := -0.38
var pivot := Node3D.new()
var spring := SpringArm3D.new()
var camera := Camera3D.new()
var model := Node3D.new()
var hand := Node3D.new()
var shown_item := "-"
var focus_id := ""
var focus_prompt := ""
var _bob := 0.0


func _ready() -> void:
	Game.register_player(pid)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.8
	add_child(col)

	add_child(model)
	model.rotation.y = PI
	_build_model()
	hand.position = Vector3(0, 0.9, 0.4)
	model.add_child(hand)

	pivot.position.y = 1.45
	add_child(pivot)
	spring.spring_length = 4.0
	spring.margin = 0.25
	var ss := SphereShape3D.new()
	ss.radius = 0.2
	spring.shape = ss
	spring.add_excluded_object(get_rid())
	pivot.add_child(spring)
	camera.fov = 62.0
	spring.add_child(camera)
	camera.current = true


func _build_model() -> void:
	_part(CylinderMesh, {"top_radius": 0.13, "bottom_radius": 0.36, "height": 1.1}, Vector3(0, 0.55, 0), Color(0.42, 0.3, 0.68))
	_part(CylinderMesh, {"top_radius": 0.2, "bottom_radius": 0.2, "height": 0.06}, Vector3(0, 0.62, 0), Color(0.85, 0.7, 0.35))
	_part(SphereMesh, {"radius": 0.2, "height": 0.4}, Vector3(0, 1.28, 0), Color(0.95, 0.78, 0.65))
	_part(SphereMesh, {"radius": 0.21, "height": 0.42}, Vector3(0, 1.31, -0.04), Color(0.4, 0.24, 0.14))
	_part(SphereMesh, {"radius": 0.025, "height": 0.05}, Vector3(0.07, 1.3, 0.18), Color(0.1, 0.08, 0.08))
	_part(SphereMesh, {"radius": 0.025, "height": 0.05}, Vector3(-0.07, 1.3, 0.18), Color(0.1, 0.08, 0.08))
	_part(CylinderMesh, {"top_radius": 0.36, "bottom_radius": 0.36, "height": 0.035}, Vector3(0, 1.44, 0), Color(0.18, 0.2, 0.42))
	var hat := _part(CylinderMesh, {"top_radius": 0.0, "bottom_radius": 0.21, "height": 0.55}, Vector3(0, 1.72, -0.02), Color(0.18, 0.2, 0.42))
	hat.rotation.x = -0.18


func _part(mesh_type, props: Dictionary, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh = mesh_type.new()
	for k in props:
		mesh.set(k, props[k])
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.75
	mi.material_override = m
	mi.position = pos
	model.add_child(mi)
	return mi


func _ui_open() -> bool:
	return hud != null and hud.is_open()


func _unhandled_input(event) -> void:
	if _ui_open():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * MOUSE_SENS
		cam_pitch = clampf(cam_pitch - event.relative.y * MOUSE_SENS, -1.15, 0.25)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact") and not event.is_echo():
		if focus_id != "":
			get_viewport().set_input_as_handled()
			var result: Dictionary = Game.interact(pid, focus_id)
			if result.has("ui") and hud != null:
				hud.open_ui(result["ui"])


func _physics_process(delta: float) -> void:
	pivot.rotation = Vector3(cam_pitch, cam_yaw, 0.0)

	var input := Vector2.ZERO
	if not _ui_open():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, cam_yaw)
	var speed := RUN if Input.is_action_pressed("run") else WALK
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if dir.length() > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
		_bob += delta * speed * 3.2
		model.position.y = absf(sin(_bob)) * 0.05
	else:
		model.position.y = lerpf(model.position.y, 0.0, minf(1.0, delta * 10.0))

	_find_focus()
	_update_hand()


func _find_focus() -> void:
	var fwd := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var probe := global_position + fwd * 0.5
	var best_d := REACH
	focus_id = ""
	focus_prompt = ""
	for n in get_tree().get_nodes_in_group("interactable"):
		var np: Vector3 = n.global_position
		var d := Vector2(np.x - probe.x, np.z - probe.z).length()
		if d >= best_d:
			continue
		var prompt: String = Game.get_prompt(pid, n.target_id)
		if prompt == "":
			continue
		best_d = d
		focus_id = n.target_id
		focus_prompt = prompt


func _update_hand() -> void:
	var item: Dictionary = Game.held.get(pid, {})
	var key := str(item.get("kind", "")) + str(item.get("plant", ""))
	if key == shown_item:
		return
	shown_item = key
	for c in hand.get_children():
		c.queue_free()
	match str(item.get("kind", "")):
		"soil":
			_hand_part(SphereMesh, {"radius": 0.17, "height": 0.26}, Vector3.ZERO, Color(0.55, 0.42, 0.28))
		"seed":
			var col: Color = Game.PLANTS[item["plant"]]["color"]
			_hand_part(BoxMesh, {"size": Vector3(0.16, 0.2, 0.04)}, Vector3.ZERO, col)
		"can":
			_hand_part(CylinderMesh, {"top_radius": 0.1, "bottom_radius": 0.12, "height": 0.2}, Vector3.ZERO, Color(0.55, 0.62, 0.66))
			var spout := _hand_part(CylinderMesh, {"top_radius": 0.015, "bottom_radius": 0.025, "height": 0.25}, Vector3(0.14, 0.06, 0), Color(0.55, 0.62, 0.66))
			spout.rotation.z = -0.9
		"plant":
			_hand_part(CylinderMesh, {"top_radius": 0.1, "bottom_radius": 0.08, "height": 0.14}, Vector3.ZERO, Color(0.64, 0.71, 0.69))
			var pc: Color = Game.PLANTS[item["plant"]]["color"]
			_hand_part(SphereMesh, {"radius": 0.11, "height": 0.22}, Vector3(0, 0.16, 0), pc)
		"wilted":
			_hand_part(SphereMesh, {"radius": 0.12, "height": 0.18}, Vector3.ZERO, Color(0.42, 0.32, 0.18))


func _hand_part(mesh_type, props: Dictionary, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh = mesh_type.new()
	for k in props:
		mesh.set(k, props[k])
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	mi.material_override = m
	mi.position = pos
	hand.add_child(mi)
	return mi
