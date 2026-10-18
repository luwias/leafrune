extends Node
## Leafrune Akadémia – a teljes játékállapot (autoload: "Game").
##
## Itt él minden, ami számít: a cserepek, a tanoncok kezében lévő tárgyak,
## a feladatok, az óra ideje és a csillagok. Ebben a fájlban nincs semmi 3D-s.
## A multihoz ezt a hoszt futtatja: a többi játékos csak kéréseket küld
## (interact), és megkapja a frissített állapotot.

signal message(text: String)
signal tasks_changed
signal lesson_ended(lesson_stars: int, all_done: bool)

enum Stage { WILTED = -1, EMPTY = 0, SOIL = 1, PLANTED = 2, SPROUT = 3, BUD = 4, GROWN = 5 }

const STAGE_NAMES := {
	-1: "hervadt", 0: "üres", 1: "földes", 2: "elültetve",
	3: "csíra", 4: "bimbó", 5: "kifejlett",
}
const LESSON_LENGTH := 300.0
const CAN_SIZE := 3

## A növények adatai. Új növény = új bejegyzés itt.
const PLANTS := {
	"holdliliom": {
		"name": "Holdliliom",
		"light": "shade",
		"grow_time": 24.0,     # másodperc a mag és a virág között, ha jól gondozod
		"thirst": 0.05,        # ennyit szárad a föld másodpercenként (1.0 = frissen locsolt)
		"special": "",
		"color": Color(0.86, 0.93, 1.0),
		"page": "Csak árnyékban nő, napon megég a szirma. Közepes vizet kér: ha kiszárad a föld, locsold meg. Ez az első növény, amit minden tanonc megtanul.",
		"question": "Melyik asztalra ülteted a Holdliliomot?",
		"answers": ["A napos asztalra", "Az árnyékos asztalra"],
		"correct": 1,
	},
	"paprany": {
		"name": "Suttogó páfrány",
		"light": "sun",
		"grow_time": 21.0,
		"thirst": 0.08,
		"special": "hum",
		"color": Color(0.42, 0.74, 0.36),
		"page": "Napfényt és sok vizet szeret. Bimbós korában dúdolni kell neki: állj mellé üres kézzel, és nyomd meg az E gombot. Dúdolás nélkül nem nyílik ki, és lassan elszomorodik.",
		"question": "Mit kér a páfrány bimbós korában?",
		"answers": ["Trágyát", "Dúdolást", "Sötétséget"],
		"correct": 1,
	},
}

var pots := {}        # cserép azonosító -> állapot
var targets := {}     # minden, amivel lehet valamit csinálni
var held := {}        # játékos azonosító -> tárgy ({} = üres kéz)
var learned := {}     # növény -> true, ha elolvasta a Herbáriumban
var quiz_done := {}   # növény -> true, ha már válaszolt a kérdésre
var quiz_bonus := {}  # növény -> true, ha jó választ adott (plusz csillag a következő leadásnál)
var tasks: Array = []
var total_stars := 0
var lesson_stars := 0
var lesson_no := 1
var lesson_time := LESSON_LENGTH


func _ready() -> void:
	_setup_inputs()
	_new_tasks()


func _setup_inputs() -> void:
	var map = {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
		"run": [KEY_SHIFT],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- regisztráció

func register_player(pid: int) -> void:
	held[pid] = {}


func register_target(id: String, data: Dictionary) -> void:
	targets[id] = data


func register_pot(id: String, light: String) -> void:
	targets[id] = {"type": "pot"}
	pots[id] = _empty_pot(light)


func _empty_pot(light: String) -> Dictionary:
	return {
		"stage": Stage.EMPTY, "plant": "", "moisture": 0.0, "growth": 0.0,
		"health": 1.0, "light": light, "hummed": false,
	}


# ---------------------------------------------------------------- idő múlása

func _process(delta: float) -> void:
	lesson_time -= delta
	if lesson_time <= 0.0:
		_end_lesson(false)

	for id in pots:
		var p: Dictionary = pots[id]
		var stage: int = p["stage"]
		if stage < Stage.PLANTED or stage > Stage.BUD:
			continue
		var info: Dictionary = PLANTS[p["plant"]]
		p["moisture"] = maxf(0.0, p["moisture"] - info["thirst"] * delta)
		var light_ok: bool = p["light"] == info["light"]
		var waiting_for_hum := _needs_hum(p)

		if p["moisture"] > 0.0 and light_ok and not waiting_for_hum:
			p["growth"] += delta
			if p["growth"] >= info["grow_time"] / 3.0:
				p["growth"] = 0.0
				p["stage"] = stage + 1
				if p["stage"] == Stage.GROWN:
					message.emit("Kifejlődött egy %s. Üres kézzel arathatod le." % info["name"])
		else:
			var drain := 0.03
			if not light_ok:
				drain = 0.05
			elif waiting_for_hum:
				drain = 0.015
			p["health"] -= drain * delta
			if p["health"] <= 0.0:
				p["stage"] = Stage.WILTED
				message.emit("Elhervadt egy %s. Szedd ki, és vidd a komposztba." % info["name"])


# ---------------------------------------------------------------- feladatok

func _new_tasks() -> void:
	tasks.clear()
	if lesson_no == 1:
		tasks.append({"plant": "holdliliom", "count": 1, "done": 0})
		tasks.append({"plant": "paprany", "count": 1, "done": 0})
	else:
		for key in PLANTS:
			tasks.append({"plant": key, "count": randi_range(1, 2), "done": 0})
	tasks_changed.emit()


func _end_lesson(all_done: bool) -> void:
	lesson_ended.emit(lesson_stars, all_done)
	lesson_no += 1
	lesson_stars = 0
	lesson_time = LESSON_LENGTH
	_new_tasks()


# ---------------------------------------------------------------- tanulás

func learn(plant: String) -> void:
	if learned.has(plant):
		return
	learned[plant] = true
	message.emit("Megtanultad: %s. Mostantól látod a cserepeken, mire van szüksége." % PLANTS[plant]["name"])


func answer_quiz(plant: String, idx: int) -> void:
	if quiz_done.has(plant):
		return
	quiz_done[plant] = true
	if idx == PLANTS[plant]["correct"]:
		quiz_bonus[plant] = true
		message.emit("Helyes! A következő leadott %s plusz egy csillagot ér." % PLANTS[plant]["name"])
	else:
		message.emit("Nem talált. A helyes válasz: %s." % PLANTS[plant]["answers"][PLANTS[plant]["correct"]])


# ---------------------------------------------------------------- tárgyak

func item_name(item: Dictionary) -> String:
	if item.is_empty():
		return "semmi"
	match item["kind"]:
		"soil":
			return "virágföld"
		"seed":
			return "%s mag" % PLANTS[item["plant"]]["name"]
		"can":
			return "öntözőkanna (%d/%d víz)" % [item["water"], CAN_SIZE]
		"plant":
			return "%s %s" % [PLANTS[item["plant"]]["name"], "★".repeat(item["stars"])]
		"wilted":
			return "hervadt növény"
	return "?"


func _same_item(a: Dictionary, b: Dictionary) -> bool:
	return a.get("kind", "") == b.get("kind", "") and a.get("plant", "") == b.get("plant", "")


func _needs_hum(p: Dictionary) -> bool:
	if p["plant"] == "":
		return false
	return PLANTS[p["plant"]]["special"] == "hum" and p["stage"] == Stage.BUD and not p["hummed"]


func _rate(p: Dictionary) -> int:
	var s := 1
	if p["health"] > 0.75:
		s = 3
	elif p["health"] > 0.4:
		s = 2
	if not learned.has(p["plant"]):
		s = mini(s, 2)
	return s


# ---------------------------------------------------------------- mit lehet csinálni

## A szöveg, ami a képernyő alján megjelenik, ha valami előtt állsz. Üres = nincs teendő.
func get_prompt(pid: int, id: String) -> String:
	var t: Dictionary = targets.get(id, {})
	if t.is_empty():
		return ""
	var h: Dictionary = held.get(pid, {})
	var k: String = h.get("kind", "")
	match t["type"]:
		"source":
			if h.is_empty():
				return "Felvesz: " + item_name(t["item"])
			if _same_item(h, t["item"]):
				return "Visszatesz"
			return ""
		"tap":
			if k == "can":
				return "Kanna megtöltése"
			return "Vízcsap"
		"compost":
			if k != "" and k != "can":
				return "Komposztba dob: " + item_name(h)
			return "Komposzt"
		"handin":
			if k == "plant":
				return "Lead: " + item_name(h)
			return "Leadópult"
		"board":
			return "Feladatok elolvasása"
		"herbarium":
			return "Herbárium kinyitása"
		"pot":
			return _pot_prompt(pots[id], h)
	return ""


func _pot_prompt(p: Dictionary, h: Dictionary) -> String:
	var k: String = h.get("kind", "")
	var stage: int = p["stage"]
	if stage == Stage.EMPTY:
		if k == "soil":
			return "Földet tesz a cserépbe"
		return "Üres cserép"
	if stage == Stage.SOIL:
		if k == "seed":
			return "Elültet: " + PLANTS[h["plant"]]["name"]
		return "Földes cserép"
	if stage == Stage.GROWN:
		if k == "":
			return "Learat: " + PLANTS[p["plant"]]["name"]
		return "Kész növény"
	if stage == Stage.WILTED:
		if k == "":
			return "Hervadt növény kiszedése"
		return "Hervadt növény"
	if k == "can":
		return "Locsolás"
	if k == "" and _needs_hum(p):
		return "Dúdolás ♪"
	return "%s · %s" % [PLANTS[p["plant"]]["name"], STAGE_NAMES[stage]]


## Rövid súgó a cserép fölé.
func pot_hint(id: String) -> String:
	var p: Dictionary = pots.get(id, {})
	if p.is_empty():
		return ""
	var stage: int = p["stage"]
	if stage == Stage.GROWN:
		return "Kész!"
	if stage == Stage.WILTED:
		return "Elhervadt"
	if stage < Stage.PLANTED:
		return ""
	var info: Dictionary = PLANTS[p["plant"]]
	var problems: PackedStringArray = []
	if p["moisture"] <= 0.0:
		problems.append("Szomjas!")
	if p["light"] != info["light"]:
		problems.append("Napfényt kér" if info["light"] == "sun" else "Árnyékot kér")
	if _needs_hum(p):
		problems.append("Dúdolj neki ♪")
	if problems.is_empty():
		return ""
	if not learned.has(p["plant"]):
		return "Valami nem jó... (Herbárium)"
	return " · ".join(problems)


## Ezt hívja a játékos, amikor megnyomja az E-t. A visszaadott {"ui": ...} ablakot nyit.
func interact(pid: int, id: String) -> Dictionary:
	var t: Dictionary = targets.get(id, {})
	if t.is_empty():
		return {}
	var h: Dictionary = held.get(pid, {})
	var k: String = h.get("kind", "")
	match t["type"]:
		"source":
			var it: Dictionary = t["item"]
			if h.is_empty():
				held[pid] = it.duplicate(true)
			elif _same_item(h, it):
				held[pid] = {}
			else:
				message.emit("Előbb tedd le, ami a kezedben van.")
		"tap":
			if k == "can":
				h["water"] = CAN_SIZE
				message.emit("Megtöltötted a kannát.")
			else:
				message.emit("Hozd ide az öntözőkannát a raktárpolcról.")
		"compost":
			if k != "" and k != "can":
				held[pid] = {}
				message.emit("A komposztba került.")
		"handin":
			_hand_in(pid, h)
		"board":
			return {"ui": "tasks"}
		"herbarium":
			return {"ui": "herbarium"}
		"pot":
			_pot_interact(pid, id, h)
	return {}


func _pot_interact(pid: int, id: String, h: Dictionary) -> void:
	var p: Dictionary = pots[id]
	var k: String = h.get("kind", "")
	var stage: int = p["stage"]
	if stage == Stage.EMPTY:
		if k == "soil":
			p["stage"] = Stage.SOIL
			held[pid] = {}
		else:
			message.emit("Előbb virágföld kell bele. A raktárpolcon találod.")
	elif stage == Stage.SOIL:
		if k == "seed":
			p["stage"] = Stage.PLANTED
			p["plant"] = h["plant"]
			p["moisture"] = 0.0
			p["growth"] = 0.0
			p["health"] = 1.0
			p["hummed"] = false
			held[pid] = {}
			message.emit("Elültetted. Ne felejtsd el meglocsolni!")
		else:
			message.emit("Most jöhet a mag. A raktárpolcon találod.")
	elif stage == Stage.GROWN:
		if k == "":
			held[pid] = {"kind": "plant", "plant": p["plant"], "stars": _rate(p)}
			pots[id] = _empty_pot(p["light"])
		else:
			message.emit("Üres kézzel tudod learatni.")
	elif stage == Stage.WILTED:
		if k == "":
			held[pid] = {"kind": "wilted"}
			pots[id] = _empty_pot(p["light"])
		else:
			message.emit("Üres kézzel tudod kiszedni.")
	else:
		if k == "can":
			if h["water"] > 0:
				h["water"] -= 1
				p["moisture"] = 1.0
			else:
				message.emit("Üres a kanna. Töltsd meg a vízcsapnál.")
		elif k == "" and _needs_hum(p):
			p["hummed"] = true
			message.emit("♪ Dúdoltál a páfránynak. Boldogan rezegnek a levelei.")


func _hand_in(pid: int, h: Dictionary) -> void:
	if h.get("kind", "") != "plant":
		message.emit("Ide kész, learatott növényt hozz.")
		return
	for t in tasks:
		if t["plant"] == h["plant"] and t["done"] < t["count"]:
			t["done"] += 1
			var s: int = h["stars"]
			if quiz_bonus.has(h["plant"]):
				s += 1
				quiz_bonus.erase(h["plant"])
			lesson_stars += s
			total_stars += s
			held[pid] = {}
			message.emit("Leadva: %s, %s" % [PLANTS[h["plant"]]["name"], "★".repeat(s)])
			tasks_changed.emit()
			if tasks.all(func(x): return x["done"] >= x["count"]):
				lesson_stars += 2
				total_stars += 2
				_end_lesson(true)
			return
	message.emit("Ez a növény most nem kell egyik feladathoz sem.")
