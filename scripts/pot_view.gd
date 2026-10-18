extends "res://scripts/interactable.gd"
## Egy cserép látványa. Minden képkockában megnézi a Game állapotát,
## és ha a szakasz változott, újraépíti a növényt.

const GS := preload("res://scripts/game_state.gd")
const DRY := Color(0.42, 0.29, 0.19)
const WET := Color(0.2, 0.13, 0.08)
const C_POT := Color(0.64, 0.71, 0.69)

var soil: MeshInstance3D
var soil_mat := StandardMaterial3D.new()
var plant_root := Node3D.new()
var label := Label3D.new()
var shown_stage := -99
var shown_plant := ""
var _t := 0.0


func _ready() -> void:
	super._ready()
	var pot_mat := StandardMaterial3D.new()
	pot_mat.albedo_color = C_POT
	pot_mat.roughness = 0.85

	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.19
	cm.height = 0.42
	body.mesh = cm
	body.material_override = pot_mat
	body.position.y = 0.21
	add_child(body)

	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.285
	rm.bottom_radius = 0.275
	rm.height = 0.07
	rim.mesh = rm
	rim.material_override = pot_mat
	rim.position.y = 0.42
	add_child(rim)

	soil = MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.25
	sm.bottom_radius = 0.25
	sm.height = 0.03
	soil.mesh = sm
	soil_mat.albedo_color = DRY
	soil_mat.roughness = 1.0
	soil.material_override = soil_mat
	soil.position.y = 0.43
	add_child(soil)

	plant_root.position.y = 0.44
	add_child(plant_root)

	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.004
	label.outline_size = 10
	label.modulate = Color(1.0, 0.95, 0.8)
	label.position.y = 1.25
	add_child(label)


func _process(delta: float) -> void:
	_t += delta
	var p: Dictionary = Game.pots.get(target_id, {})
	if p.is_empty():
		return
	if p["stage"] != shown_stage or p["plant"] != shown_plant:
		shown_stage = p["stage"]
		shown_plant = p["plant"]
		_rebuild()
	soil.visible = shown_stage != Game.Stage.EMPTY
	soil_mat.albedo_color = DRY.lerp(WET, clampf(p["moisture"] * 1.5, 0.0, 1.0))
	label.text = Game.pot_hint(target_id)
	plant_root.rotation.z = sin(_t * 1.3 + position.x) * 0.03
	if shown_stage == Game.Stage.GROWN:
		plant_root.rotation.y += delta * 0.2


func _rebuild() -> void:
	for c in plant_root.get_children():
		c.queue_free()
	var stem := Color(0.3, 0.55, 0.25)
	var leaf := Color(0.38, 0.66, 0.32)
	match shown_stage:
		GS.Stage.PLANTED:
			_sphere(Vector3(0, 0.02, 0), 0.04, Color(0.55, 0.4, 0.2))
		GS.Stage.SPROUT:
			_cyl(Vector3(0, 0.1, 0), 0.015, 0.2, stem)
			_sphere(Vector3(0.06, 0.18, 0), 0.06, leaf, Vector3(1.3, 0.35, 0.7))
			_sphere(Vector3(-0.06, 0.15, 0), 0.06, leaf, Vector3(1.3, 0.35, 0.7))
		GS.Stage.BUD:
			_cyl(Vector3(0, 0.2, 0), 0.02, 0.4, stem)
			for i in 3:
				var a: float = i * TAU / 3.0
				_sphere(Vector3(cos(a) * 0.1, 0.15, sin(a) * 0.1), 0.08, leaf, Vector3(1.4, 0.35, 0.7))
			var bud_col: Color = Game.PLANTS[shown_plant]["color"].darkened(0.3)
			_sphere(Vector3(0, 0.42, 0), 0.07, bud_col, Vector3(0.8, 1.3, 0.8))
		GS.Stage.GROWN:
			if shown_plant == "holdliliom":
				_build_lily()
			else:
				_build_fern()
		GS.Stage.WILTED:
			var brown := Color(0.42, 0.32, 0.18)
			var s := _cyl(Vector3(0.05, 0.15, 0), 0.02, 0.32, brown)
			s.rotation.z = -0.6
			_sphere(Vector3(0.16, 0.24, 0), 0.07, brown, Vector3(1.2, 0.5, 0.8))


func _build_lily() -> void:
	var c: Color = Game.PLANTS["holdliliom"]["color"]
	_cyl(Vector3(0, 0.28, 0), 0.02, 0.56, Color(0.3, 0.55, 0.25))
	for i in 3:
		var a: float = i * TAU / 3.0
		_sphere(Vector3(cos(a) * 0.12, 0.18, sin(a) * 0.12), 0.1, Color(0.36, 0.62, 0.3), Vector3(1.5, 0.3, 0.7))
	for i in 6:
		var a: float = i * TAU / 6.0
		var petal := _sphere(Vector3(cos(a) * 0.1, 0.6, sin(a) * 0.1), 0.08, c, Vector3(0.7, 0.35, 1.6), 0.6)
		petal.rotation.y = -a
		petal.rotation.x = 0.5
	_sphere(Vector3(0, 0.62, 0), 0.04, Color(1.0, 0.85, 0.45), Vector3.ONE, 1.5)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 0.85, 1.0)
	glow.light_energy = 0.6
	glow.omni_range = 1.2
	glow.position.y = 0.65
	plant_root.add_child(glow)


func _build_fern() -> void:
	var c: Color = Game.PLANTS["paprany"]["color"]
	for i in 7:
		var a: float = i * TAU / 7.0
		var pivot := Node3D.new()
		pivot.rotation.y = -a   # a pivot +X tengelye a levél iránya
		plant_root.add_child(pivot)
		var frond := _sphere(Vector3(0.13, 0.26, 0), 0.07, c, Vector3(0.6, 4.0, 0.25), 0.0, pivot)
		frond.rotation.z = -0.55   # a levél csúcsa kifelé dől
	_sphere(Vector3(0, 0.08, 0), 0.12, c.darkened(0.2), Vector3(1.4, 0.6, 1.4))


func _sphere(pos: Vector3, r: float, col: Color, scl := Vector3.ONE, emit := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	if parent == null:
		parent = plant_root
	parent.add_child(mi)
	return mi


func _cyl(pos: Vector3, r: float, h: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.7
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.8
	mi.material_override = m
	mi.position = pos
	plant_root.add_child(mi)
	return mi
