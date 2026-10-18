extends CanvasLayer
## Kezelőfelület: feladatok, óra, csillagok, kézben lévő tárgy, súgó,
## valamint a Herbárium és a feladattábla ablaka.

const GOLD := Color(0.95, 0.82, 0.5)
const TEXT := Color(0.96, 0.94, 0.88)
const MUTED := Color(0.72, 0.78, 0.72)

var player: Node = null
var open_name := ""

var task_panel: PanelContainer
var task_rows: Label
var task_title: Label
var info_panel: PanelContainer
var info_label: Label
var hand_panel: PanelContainer
var hand_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_label: Label
var toast_time := 0.0
var help_label: Label

var herb_panel: PanelContainer
var herb_title: Label
var herb_facts: Label
var herb_body: Label
var herb_learn: Button
var herb_q: Label
var herb_answers: HBoxContainer
var cur_plant := "holdliliom"

var board_panel: PanelContainer
var board_label: Label


func _ready() -> void:
	task_panel = _panel()
	var tv := VBoxContainer.new()
	task_panel.add_child(tv)
	task_title = _label("", 14, GOLD)
	tv.add_child(task_title)
	task_rows = _label("", 19)
	tv.add_child(task_rows)
	add_child(task_panel)

	info_panel = _panel()
	info_label = _label("", 19)
	info_panel.add_child(info_label)
	add_child(info_panel)

	hand_panel = _panel()
	hand_label = _label("", 18)
	hand_panel.add_child(hand_label)
	add_child(hand_panel)

	prompt_panel = _panel(0.9)
	prompt_label = _label("", 22, GOLD)
	prompt_panel.add_child(prompt_label)
	add_child(prompt_panel)

	toast_label = _label("", 26)
	toast_label.add_theme_constant_override("outline_size", 10)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast_label.modulate.a = 0.0
	add_child(toast_label)

	help_label = _label("WASD: mozgás · Shift: futás · kattintás: kamera egérrel · E: használat · Esc: egér elengedése", 15, MUTED)
	help_label.add_theme_constant_override("outline_size", 6)
	help_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	add_child(help_label)

	_build_herbarium()
	_build_board()

	Game.message.connect(toast)
	Game.tasks_changed.connect(_refresh_tasks)
	Game.lesson_ended.connect(_on_lesson_ended)
	_refresh_tasks()
	toast("Üdv a Leafrune Akadémián! Nézd meg a feladattáblát a bejárat mellett.")


# ---------------------------------------------------------------- építőkockák

func _panel(alpha := 0.82) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.11, 0.09, alpha)
	sb.border_color = Color(0.85, 0.72, 0.45, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- frissítés

func _process(delta: float) -> void:
	var vs := get_viewport().get_visible_rect().size

	var t := maxf(0.0, Game.lesson_time)
	info_label.text = "%d. óra · %d:%02d    ★ %d" % [Game.lesson_no, int(t) / 60, int(t) % 60, Game.total_stars]

	var pid: int = player.pid if player != null else 1
	hand_label.text = "Kézben: " + Game.item_name(Game.held.get(pid, {}))

	var prompt: String = player.focus_prompt if player != null else ""
	prompt_panel.visible = prompt != "" and open_name == ""
	prompt_label.text = "[E]  " + prompt

	for p in [task_panel, info_panel, hand_panel, prompt_panel]:
		p.reset_size()
	toast_label.reset_size()
	help_label.reset_size()

	task_panel.position = Vector2(16, 16)
	info_panel.position = Vector2(vs.x - info_panel.size.x - 16, 16)
	hand_panel.position = Vector2(16, vs.y - hand_panel.size.y - 16)
	prompt_panel.position = Vector2((vs.x - prompt_panel.size.x) / 2.0, vs.y - prompt_panel.size.y - 80)
	toast_label.position = Vector2((vs.x - toast_label.size.x) / 2.0, vs.y * 0.16)
	help_label.position = Vector2(vs.x - help_label.size.x - 16, vs.y - help_label.size.y - 16)
	herb_panel.position = (vs - herb_panel.size) / 2.0
	board_panel.position = (vs - board_panel.size) / 2.0

	if toast_time > 0.0:
		toast_time -= delta
		toast_label.modulate.a = clampf(toast_time / 0.5, 0.0, 1.0)


func toast(text: String) -> void:
	toast_label.text = text
	toast_time = 4.0
	toast_label.modulate.a = 1.0


func _tasks_text() -> String:
	var lines: PackedStringArray = []
	for t in Game.tasks:
		var plant_name: String = Game.PLANTS[t["plant"]]["name"]
		var mark := "✓ " if t["done"] >= t["count"] else "•  "
		lines.append("%s%s  %d/%d" % [mark, plant_name, t["done"], t["count"]])
	return "\n".join(lines)


func _refresh_tasks() -> void:
	task_title.text = "FELADATOK · %d. ÓRA" % Game.lesson_no
	task_rows.text = _tasks_text()
	if board_label != null:
		board_label.text = _board_text()


func _on_lesson_ended(stars: int, all_done: bool) -> void:
	if all_done:
		toast("Minden feladat kész! +2 ★ jutalom. Ebben az órában %d ★ gyűlt." % stars)
	else:
		toast("Vége az órának. Ebben az órában %d ★ gyűlt. Jön a következő!" % stars)


# ---------------------------------------------------------------- ablakok

func is_open() -> bool:
	return open_name != ""


func open_ui(ui_name: String) -> void:
	close_ui()
	open_name = ui_name
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ui_name == "herbarium":
		_show_page(cur_plant)
		herb_panel.visible = true
	elif ui_name == "tasks":
		board_label.text = _board_text()
		board_panel.visible = true


func close_ui() -> void:
	open_name = ""
	herb_panel.visible = false
	board_panel.visible = false


func _unhandled_input(event) -> void:
	if open_name != "" and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		close_ui()
		get_viewport().set_input_as_handled()


func _build_board() -> void:
	board_panel = _panel(0.95)
	board_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	board_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	board_panel.add_child(v)
	v.add_child(_label("FELADATTÁBLA", 14, GOLD))
	board_label = _label("", 20)
	board_label.custom_minimum_size = Vector2(520, 0)
	board_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(board_label)
	v.add_child(_button("Bezár (Esc)", close_ui))
	add_child(board_panel)


func _board_text() -> String:
	var t := "%d. óra feladatai:\n\n%s\n\nNevelj fel ilyen növényeket, és vidd őket a Leadópulthoz a hátsó fal mellett. Ha nem tudod, mire van szüksége egy növénynek, nézd meg a Herbáriumban (jobb hátsó sarok)." % [Game.lesson_no, _tasks_text()]
	return t


func _build_herbarium() -> void:
	herb_panel = _panel(0.96)
	herb_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	herb_panel.visible = false
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	herb_panel.add_child(root)
	root.add_child(_label("HERBÁRIUM", 14, GOLD))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	root.add_child(hb)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(220, 0)
	hb.add_child(list)
	for key in Game.PLANTS:
		var k: String = key
		list.add_child(_button(Game.PLANTS[k]["name"], _show_page.bind(k)))

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.custom_minimum_size = Vector2(500, 0)
	hb.add_child(page)
	herb_title = _label("", 32, GOLD)
	page.add_child(herb_title)
	herb_facts = _label("", 18, MUTED)
	page.add_child(herb_facts)
	herb_body = _label("", 19)
	herb_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	herb_body.custom_minimum_size = Vector2(500, 0)
	page.add_child(herb_body)
	herb_learn = _button("", _on_learn)
	page.add_child(herb_learn)
	herb_q = _label("", 19, GOLD)
	herb_q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	herb_q.custom_minimum_size = Vector2(500, 0)
	page.add_child(herb_q)
	herb_answers = HBoxContainer.new()
	herb_answers.add_theme_constant_override("separation", 8)
	page.add_child(herb_answers)

	root.add_child(_button("Bezár (Esc)", close_ui))
	add_child(herb_panel)


func _show_page(key: String) -> void:
	cur_plant = key
	var info: Dictionary = Game.PLANTS[key]
	herb_title.text = info["name"]
	var light := "árnyék" if info["light"] == "shade" else "napfény"
	var water := "sok" if info["thirst"] >= 0.07 else "közepes"
	var special := "dúdolás bimbós korban" if info["special"] == "hum" else "nincs"
	herb_facts.text = "Fény: %s   ·   Víz: %s   ·   Különleges: %s" % [light, water, special]
	herb_body.text = info["page"]

	var learned: bool = Game.learned.has(key)
	herb_learn.text = "Megtanultad ✓" if learned else "Elolvastam, megtanultam"
	herb_learn.disabled = learned

	for c in herb_answers.get_children():
		c.queue_free()
	herb_q.visible = learned
	if not learned:
		return
	if Game.quiz_done.has(key):
		herb_q.text = "Kérdés: " + info["question"] + "\nMár válaszoltál erre a kérdésre."
		return
	herb_q.text = "Kérdés (jó válasz = +1 ★ a következő leadásnál): " + info["question"]
	var answers: Array = info["answers"]
	for i in answers.size():
		var idx: int = i
		herb_answers.add_child(_button(answers[i], _on_answer.bind(key, idx)))


func _on_learn() -> void:
	Game.learn(cur_plant)
	_show_page(cur_plant)


func _on_answer(key: String, idx: int) -> void:
	Game.answer_quiz(key, idx)
	_show_page(key)
