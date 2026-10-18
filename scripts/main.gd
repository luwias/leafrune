extends Node3D
## Leafrune Akadémia – fő jelenet.
## Felépíti az üvegházat, a bútorokat, a cserepeket, a tanoncot és a kezelőfelületet.
## Ha van Blenderből exportált üvegház-váz (assets/models/greenhouse.glb),
## a helyőrző falak, padló és tető helyett azt használja.

const PotView := preload("res://scripts/pot_view.gd")
const Interactable := preload("res://scripts/interactable.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/hud.gd")
const SHELL_GLB := "res://assets/models/greenhouse.glb"

# Méretek méterben. A Blender-szkript ugyanezeket használja.
const ROOM_W := 16.0     # x irány
const ROOM_D := 12.0     # z irány, a bejárat a +z oldalon
const WALL_H := 4.2
const RIDGE_H := 5.6
const DOOR_HALF := 1.1
const BAYS_X := 7
const BAYS_Z := 5

const C_FLOOR := Color(0.78, 0.68, 0.52)
const C_MOSAIC := Color(0.6, 0.52, 0.36)
const C_STONE := Color(0.8, 0.72, 0.56)
const C_FRAME := Color(0.82, 0.72, 0.46)
const C_GLASS := Color(0.8, 0.9, 0.92, 0.16)
const C_WOOD := Color(0.72, 0.48, 0.28)
const C_WOOD_DK := Color(0.45, 0.29, 0.17)
const C_LEAF := Color(0.3, 0.52, 0.26)
const C_LEAF_DK := Color(0.18, 0.36, 0.18)
const C_PAPER := Color(0.93, 0.88, 0.74)

var fire_light: OmniLight3D
var _mats := {}
var _t := 0.0


func _ready() -> void:
	_build_environment()
	_build_shell()
	_build_furniture()
	_build_stations()

	var hud := HudScript.new()
	add_child(hud)
	var player := PlayerScript.new()
	player.position = Vector3(0, 0.2, 4.2)
	player.hud = hud
	add_child(player)
	hud.player = player


func _process(delta: float) -> void:
	_t += delta
	if fire_light != null:
		fire_light.light_energy = 2.4 + sin(_t * 9.0) * 0.25 + sin(_t * 23.0) * 0.15


# ---------------------------------------------------------------- segédek

func mat(c: Color, rough := 0.8, metal := 0.0, emit_e := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [c, rough, metal, emit_e]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit_e
	_mats[key] = m
	return m


func box(parent: Node, pos: Vector3, size: Vector3, m: Material, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		solid(mi.global_position if mi.is_inside_tree() else pos, size)
	return mi


func cyl(parent: Node, pos: Vector3, top_r: float, bot_r: float, h: float, m: Material, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(top_r, bot_r)
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func sphere(parent: Node, pos: Vector3, r: float, m: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func solid(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)


func glass(pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := box(self, pos, size, mat(C_GLASS, 0.05, 0.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func sign_label(parent: Node, pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 34
	l.pixel_size = 0.005
	l.outline_size = 10
	l.modulate = Color(1.0, 0.92, 0.7)
	l.position = pos
	parent.add_child(l)


func _sz(along_x: bool, a: float, h: float, t: float) -> Vector3:
	return Vector3(a, h, t) if along_x else Vector3(t, h, a)


# ---------------------------------------------------------------- fények, ég

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.42, 0.52, 0.72)
	psm.sky_horizon_color = Color(0.93, 0.8, 0.62)
	psm.ground_horizon_color = Color(0.7, 0.65, 0.5)
	psm.ground_bottom_color = Color(0.3, 0.32, 0.22)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.08
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.82, 0.66)
	env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)


# ---------------------------------------------------------------- üvegház-váz

func _build_shell() -> void:
	var hw := ROOM_W / 2.0
	var hd := ROOM_D / 2.0
	# Ütközők: mindig a játék rakja le őket, a Blender-modelltől függetlenül.
	solid(Vector3(0, -0.1, 1.0), Vector3(ROOM_W + 2.0, 0.2, ROOM_D + 4.0))
	solid(Vector3(0, WALL_H / 2.0, -hd - 0.1), Vector3(ROOM_W, WALL_H, 0.2))
	solid(Vector3(-hw - 0.1, WALL_H / 2.0, 0), Vector3(0.2, WALL_H, ROOM_D))
	solid(Vector3(hw + 0.1, WALL_H / 2.0, 0), Vector3(0.2, WALL_H, ROOM_D))
	var seg := hw - DOOR_HALF
	solid(Vector3(-(DOOR_HALF + seg / 2.0), WALL_H / 2.0, hd + 0.1), Vector3(seg, WALL_H, 0.2))
	solid(Vector3(DOOR_HALF + seg / 2.0, WALL_H / 2.0, hd + 0.1), Vector3(seg, WALL_H, 0.2))
	solid(Vector3(0, WALL_H / 2.0, hd + 0.9), Vector3(DOOR_HALF * 2.0 + 0.4, WALL_H, 0.2))

	# Kint: fű és pár távoli fa
	box(self, Vector3(0, -0.13, 0), Vector3(90, 0.02, 90), mat(Color(0.36, 0.5, 0.26)))
	for i in 14:
		var a: float = i * TAU / 14.0 + 0.3
		var r: float = 17.0 + float(i % 3) * 3.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		cyl(self, p + Vector3(0, 1.2, 0), 0.25, 0.35, 2.4, mat(C_WOOD_DK))
		sphere(self, p + Vector3(0, 3.4, 0), 1.9, mat(C_LEAF), Vector3(1, 1.15, 1))

	if ResourceLoader.exists(SHELL_GLB):
		var shell: Node3D = load(SHELL_GLB).instantiate()
		add_child(shell)
		for mi in shell.find_children("*", "MeshInstance3D", true, false):
			var m = mi.get_active_material(0)
			if m is BaseMaterial3D and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		_placeholder_shell()


func _placeholder_shell() -> void:
	var hw := ROOM_W / 2.0
	var hd := ROOM_D / 2.0
	box(self, Vector3(0, -0.1, 0), Vector3(ROOM_W, 0.2, ROOM_D), mat(C_FLOOR, 0.9))
	box(self, Vector3(0, -0.1, hd + 0.5), Vector3(DOOR_HALF * 2.0 + 0.4, 0.2, 1.0), mat(C_STONE, 0.9))
	cyl(self, Vector3(0, 0.005, 0.6), 3.4, 3.4, 0.01, mat(C_MOSAIC, 0.9))
	cyl(self, Vector3(0, 0.01, 0.6), 3.1, 3.1, 0.01, mat(C_FLOOR, 0.9))

	_wall(Vector3(0, 0, -hd), ROOM_W, true, BAYS_X, false)
	_wall(Vector3(0, 0, hd), ROOM_W, true, BAYS_X, true)
	_wall(Vector3(-hw, 0, 0), ROOM_D, false, BAYS_Z, false)
	_wall(Vector3(hw, 0, 0), ROOM_D, false, BAYS_Z, false)

	# Nyeregtető üvegből, bordákkal
	var rise := RIDGE_H - WALL_H
	var slope_len := sqrt(hd * hd + rise * rise)
	var ang := atan2(rise, hd)
	var frame := mat(C_FRAME, 0.4, 0.5)
	for s in [-1.0, 1.0]:
		var g: MeshInstance3D = glass(Vector3(0, WALL_H + rise / 2.0, s * hd / 2.0), Vector3(ROOM_W, 0.03, slope_len))
		g.rotation.x = s * ang
		for i in BAYS_X + 1:
			var x: float = -hw + i * ROOM_W / BAYS_X
			var rib: MeshInstance3D = box(self, Vector3(x, WALL_H + rise / 2.0, s * hd / 2.0), Vector3(0.1, 0.12, slope_len), frame)
			rib.rotation.x = s * ang
	box(self, Vector3(0, RIDGE_H, 0), Vector3(ROOM_W, 0.16, 0.16), frame)
	# Oromzat a két oldalfalon
	for sx in [-1.0, 1.0]:
		var tri := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(ROOM_D, rise, 0.03)
		tri.mesh = pm
		tri.material_override = mat(C_GLASS, 0.05)
		tri.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tri.position = Vector3(sx * hw, WALL_H + rise / 2.0, 0)
		tri.rotation.y = PI / 2.0
		add_child(tri)


func _wall(center: Vector3, length: float, along_x: bool, bays: int, door: bool) -> void:
	var bw := length / bays
	var frame := mat(C_FRAME, 0.4, 0.5)
	for i in bays + 1:
		var off: float = -length / 2.0 + i * bw
		var pos: Vector3 = center + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
		box(self, pos + Vector3(0, WALL_H / 2.0, 0), Vector3(0.14, WALL_H, 0.14), frame)
	for i in bays:
		var mid: float = -length / 2.0 + (i + 0.5) * bw
		var pos: Vector3 = center + (Vector3(mid, 0, 0) if along_x else Vector3(0, 0, mid))
		var a := bw - 0.14
		var is_door: bool = door and i == int(bays / 2.0)
		if not is_door:
			box(self, pos + Vector3(0, 0.3, 0), _sz(along_x, a, 0.6, 0.2), mat(C_STONE, 0.9))
			glass(pos + Vector3(0, (0.6 + WALL_H) / 2.0, 0), _sz(along_x, a, WALL_H - 0.6, 0.03))
			box(self, pos + Vector3(0, 1.75, 0), _sz(along_x, 0.06, 2.3, 0.06), frame)
			box(self, pos + Vector3(0, 1.8, 0), _sz(along_x, a, 0.05, 0.05), frame)
		else:
			glass(pos + Vector3(0, (3.0 + WALL_H) / 2.0, 0), _sz(along_x, a, WALL_H - 3.0, 0.03))
		box(self, pos + Vector3(0, 2.95, 0), _sz(along_x, a, 0.07, 0.07), frame)
		box(self, pos + Vector3(0, WALL_H - 0.05, 0), _sz(along_x, a, 0.1, 0.12), frame)


# ---------------------------------------------------------------- bútorok, díszek

func _bench(center: Vector3, length: float, along_x: bool) -> void:
	var depth := 0.95
	var h := 0.85
	var wood := mat(C_WOOD, 0.7)
	var dark := mat(C_WOOD_DK, 0.8)
	box(self, center + Vector3(0, h - 0.04, 0), _sz(along_x, length, 0.08, depth), wood)
	box(self, center + Vector3(0, h - 0.16, 0), _sz(along_x, length - 0.1, 0.16, depth - 0.1), dark)
	box(self, center + Vector3(0, 0.22, 0), _sz(along_x, length - 0.2, 0.05, depth - 0.15), wood)
	for sa in [-1.0, 1.0]:
		for sd in [-1.0, 1.0]:
			var off: Vector3 = Vector3(sa * (length / 2.0 - 0.12), h / 2.0, sd * (depth / 2.0 - 0.08))
			if not along_x:
				off = Vector3(sd * (depth / 2.0 - 0.08), h / 2.0, sa * (length / 2.0 - 0.12))
			box(self, center + off, Vector3(0.09, h, 0.09), dark)
	solid(center + Vector3(0, h / 2.0, 0), _sz(along_x, length, h, depth))


func _build_furniture() -> void:
	# Napos asztal a hátsó fal mentén
	_bench(Vector3(0, 0, -4.9), 7.4, true)
	for i in 5:
		var id := "pot_sun_%d" % i
		Game.register_pot(id, "sun")
		var p := PotView.new()
		p.target_id = id
		p.position = Vector3(-2.8 + i * 1.4, 0.85, -4.9)
		add_child(p)
	sign_label(self, Vector3(0, 1.9, -5.4), "Napos asztal")

	# Árnyékos asztal a bal fal mentén, lombsátor alatt
	_bench(Vector3(-6.9, 0, 0.6), 5.0, false)
	for i in 4:
		var id := "pot_shade_%d" % i
		Game.register_pot(id, "shade")
		var p := PotView.new()
		p.target_id = id
		p.position = Vector3(-6.9, 0.85, -0.9 + i * 1.0)
		add_child(p)
	var leaf := mat(C_LEAF_DK, 0.9)
	box(self, Vector3(-6.75, 2.75, 0.6), Vector3(2.3, 0.1, 6.0), leaf)
	for z in [-2.2, 3.4]:
		cyl(self, Vector3(-5.7, 1.375, z), 0.05, 0.06, 2.75, mat(C_WOOD_DK))
	for i in 9:
		var z: float = -2.2 + i * 0.7
		sphere(self, Vector3(-6.75 + (i % 2) * 0.5 - 0.25, 2.85, z), 0.55, mat(C_LEAF), Vector3(1.3, 0.55, 1.0))
		cyl(self, Vector3(-5.75, 2.2 - (i % 3) * 0.2, z), 0.02, 0.02, 1.1 + (i % 3) * 0.4, mat(C_LEAF))
	sign_label(self, Vector3(-6.2, 2.0, 0.6), "Árnyékos asztal")

	# Központi fa kőkarikában
	cyl(self, Vector3(0, 0.22, 0.6), 1.5, 1.6, 0.45, mat(C_STONE, 0.9), true)
	cyl(self, Vector3(0, 0.45, 0.6), 1.38, 1.38, 0.02, mat(Color(0.3, 0.22, 0.14)))
	cyl(self, Vector3(0, 2.0, 0.6), 0.22, 0.42, 3.2, mat(Color(0.55, 0.36, 0.22), 0.9))
	for v in [Vector3(0, 3.7, 0.6), Vector3(0.9, 3.3, 0.3), Vector3(-0.8, 3.4, 1.0), Vector3(0.2, 3.3, 1.5), Vector3(-0.3, 4.2, 0.4)]:
		sphere(self, v, 1.05, mat(C_LEAF, 0.85), Vector3(1.2, 0.9, 1.2))

	# Kandalló a bejárat jobb oldalán
	var stone := mat(Color(0.7, 0.6, 0.45), 0.95)
	box(self, Vector3(4.2, 1.1, 5.55), Vector3(2.4, 2.2, 0.8), stone, true)
	box(self, Vector3(4.2, 0.55, 5.14), Vector3(1.2, 0.9, 0.05), mat(Color(0.08, 0.05, 0.04)))
	box(self, Vector3(4.2, 2.25, 5.3), Vector3(2.7, 0.12, 1.1), stone)
	box(self, Vector3(4.2, 3.6, 5.7), Vector3(1.0, 2.8, 0.6), stone)
	sphere(self, Vector3(4.2, 0.3, 5.2), 0.25, mat(Color(1.0, 0.55, 0.15), 0.5, 0.0, 4.0), Vector3(1.3, 0.8, 0.6))
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.6, 0.3)
	fire_light.omni_range = 7.0
	fire_light.shadow_enabled = true
	fire_light.position = Vector3(4.2, 0.8, 4.8)
	add_child(fire_light)

	# Kerek asztal teáskannával a fa és a kandalló között
	cyl(self, Vector3(3.6, 0.38, 2.9), 0.12, 0.25, 0.76, mat(C_WOOD_DK), true)
	cyl(self, Vector3(3.6, 0.78, 2.9), 0.75, 0.75, 0.05, mat(C_WOOD, 0.6))
	sphere(self, Vector3(3.5, 0.9, 2.8), 0.11, mat(Color(0.85, 0.45, 0.3), 0.4))

	# Lógó indák a tetőbordákról
	for i in 10:
		var x: float = -6.0 + i * 1.35
		var z: float = -3.5 if i % 2 == 0 else 2.5
		var vlen: float = 0.8 + float(i % 4) * 0.35
		cyl(self, Vector3(x, WALL_H + 0.3 - vlen / 2.0, z), 0.02, 0.025, vlen, mat(C_LEAF))
		sphere(self, Vector3(x, WALL_H + 0.3 - vlen, z), 0.12, mat(C_LEAF), Vector3(1.2, 0.6, 1.2))


# ---------------------------------------------------------------- állomások

func _station(id: String, pos: Vector3, data: Dictionary, sign_text: String) -> Node3D:
	Game.register_target(id, data)
	var n := Interactable.new()
	n.target_id = id
	n.position = pos
	add_child(n)
	if sign_text != "":
		sign_label(n, Vector3(0, 0.9, 0), sign_text)
	return n


func _build_stations() -> void:
	var wood := mat(C_WOOD, 0.7)
	var dark := mat(C_WOOD_DK, 0.8)

	# Raktárpolc a jobb fal mentén
	box(self, Vector3(7.35, 0.45, -0.2), Vector3(1.1, 0.9, 4.8), wood, true)
	box(self, Vector3(7.75, 1.6, -0.2), Vector3(0.35, 1.4, 4.8), dark)
	for y in [1.25, 1.75]:
		box(self, Vector3(7.6, y, -0.2), Vector3(0.6, 0.05, 4.8), wood)
	for i in 6:
		cyl(self, Vector3(7.6, 1.42 + (i % 2) * 0.5, -2.2 + i * 0.8), 0.12, 0.09, 0.28, mat(Color(0.64, 0.71, 0.69)))

	var soil := _station("src_soil", Vector3(7.1, 0.9, -2.0), {"type": "source", "item": {"kind": "soil"}}, "Virágföld")
	sphere(soil, Vector3(0, 0.22, 0), 0.32, mat(Color(0.62, 0.5, 0.34), 0.95), Vector3(1.0, 0.75, 0.8))

	var seed_l := _station("src_seed_holdliliom", Vector3(7.1, 0.9, -0.8), {"type": "source", "item": {"kind": "seed", "plant": "holdliliom"}}, "Holdliliom mag")
	box(seed_l, Vector3(0, 0.1, 0), Vector3(0.45, 0.2, 0.45), dark)
	box(seed_l, Vector3(0, 0.21, 0), Vector3(0.4, 0.02, 0.4), mat(Color(0.75, 0.85, 1.0)))

	var seed_p := _station("src_seed_paprany", Vector3(7.1, 0.9, 0.4), {"type": "source", "item": {"kind": "seed", "plant": "paprany"}}, "Páfrány mag")
	box(seed_p, Vector3(0, 0.1, 0), Vector3(0.45, 0.2, 0.45), dark)
	box(seed_p, Vector3(0, 0.21, 0), Vector3(0.4, 0.02, 0.4), mat(Color(0.45, 0.72, 0.38)))

	var can := _station("src_can", Vector3(7.1, 0.9, 1.6), {"type": "source", "item": {"kind": "can", "water": 0}}, "Öntözőkanna")
	cyl(can, Vector3(0, 0.15, 0), 0.13, 0.15, 0.3, mat(Color(0.55, 0.62, 0.66), 0.4, 0.6))
	var spout := cyl(can, Vector3(0.2, 0.22, 0), 0.02, 0.03, 0.35, mat(Color(0.55, 0.62, 0.66), 0.4, 0.6))
	spout.rotation.z = -0.9

	# Vízcsap a jobb első sarokban
	var tap := _station("tap", Vector3(6.9, 0, 4.4), {"type": "tap"}, "Vízcsap")
	box(tap, Vector3(0.3, 0.45, 0), Vector3(1.0, 0.9, 1.1), mat(C_STONE, 0.6))
	box(tap, Vector3(0.3, 0.88, 0), Vector3(0.8, 0.06, 0.9), mat(Color(0.5, 0.6, 0.65), 0.2))
	cyl(tap, Vector3(0.7, 1.4, 0), 0.04, 0.04, 1.1, mat(Color(0.75, 0.6, 0.35), 0.3, 0.8))
	solid(Vector3(7.2, 0.45, 4.4), Vector3(1.0, 0.9, 1.1))

	# Herbárium a jobb hátsó sarokban
	var herb := _station("herbarium", Vector3(5.6, 0, -4.9), {"type": "herbarium"}, "")
	cyl(herb, Vector3(0, 0.5, 0), 0.12, 0.2, 1.0, dark, true)
	var book_l := box(herb, Vector3(-0.2, 1.08, 0), Vector3(0.38, 0.04, 0.5), mat(C_PAPER, 0.9))
	book_l.rotation.z = 0.12
	var book_r := box(herb, Vector3(0.2, 1.08, 0), Vector3(0.38, 0.04, 0.5), mat(C_PAPER, 0.9))
	book_r.rotation.z = -0.12
	box(herb, Vector3(0, 1.04, 0), Vector3(0.82, 0.03, 0.56), mat(Color(0.35, 0.2, 0.3)))
	var candle := OmniLight3D.new()
	candle.light_color = Color(1.0, 0.8, 0.5)
	candle.light_energy = 0.8
	candle.omni_range = 2.5
	candle.position = Vector3(0.45, 1.4, 0)
	herb.add_child(candle)
	sign_label(herb, Vector3(0, 1.6, 0), "Herbárium")

	# Leadópult a bal hátsó sarokban
	var hand_in := _station("handin", Vector3(-5.0, 0, -5.1), {"type": "handin"}, "")
	box(hand_in, Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 0.8), wood)
	box(hand_in, Vector3(0, 1.02, 0), Vector3(2.1, 0.05, 0.9), dark)
	sphere(hand_in, Vector3(0.6, 1.1, 0), 0.08, mat(Color(0.9, 0.75, 0.35), 0.3, 0.9))
	solid(Vector3(-5.0, 0.5, -5.1), Vector3(2.0, 1.0, 0.8))
	sign_label(hand_in, Vector3(0, 1.6, 0), "Leadópult")

	# Feladattábla a bejárat bal oldalán
	var board := _station("board", Vector3(-3.4, 0, 5.6), {"type": "board"}, "")
	for sx in [-0.75, 0.75]:
		box(board, Vector3(sx, 0.9, 0), Vector3(0.08, 1.8, 0.08), dark)
	box(board, Vector3(0, 1.45, 0), Vector3(1.6, 0.9, 0.06), mat(Color(0.5, 0.36, 0.24), 0.9))
	for i in 3:
		var note: MeshInstance3D = box(board, Vector3(-0.45 + i * 0.45, 1.45, -0.04), Vector3(0.3, 0.38, 0.01), mat(C_PAPER, 0.9))
		note.rotation.z = (i - 1) * 0.08
	solid(Vector3(-3.4, 0.9, 5.6), Vector3(1.6, 1.8, 0.2))
	sign_label(board, Vector3(0, 2.15, 0), "Feladattábla")

	# Komposzt a bal első sarokban
	var compost := _station("compost", Vector3(-6.9, 0, 4.9), {"type": "compost"}, "")
	cyl(compost, Vector3(0, 0.4, 0), 0.45, 0.4, 0.8, mat(Color(0.5, 0.34, 0.2), 0.9), true)
	cyl(compost, Vector3(0, 0.8, 0), 0.42, 0.42, 0.02, mat(Color(0.25, 0.18, 0.1)))
	sign_label(compost, Vector3(0, 1.3, 0), "Komposzt")
