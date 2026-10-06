extends Node2D

@onready var character = $Character
@onready var color_btn = $TestPanel/ColorBtn
@onready var slider_a = $TestPanel/ShineSlider   # первый ползунок
@onready var slider_b = $TestPanel/SatSlider     # второй ползунок
@onready var tabs_bar = $Tabs
@onready var layer_bar = $LayerBar
@onready var grid = $VariantGrid

# Где лежит палитра кружочков и кнопка ресниц (подвинь в Инспекторе)
@export var palette_pos := Vector2(1250, 820)
@export var palette_width := 900.0
@export var circle_size := 88.0
@export var lashes_pos := Vector2(1250, 700)

# Ползунки вкладок: ключ в паспорте и диапазон
const HAIR_SLIDERS := {
	"a": {"key": "hair_shine", "min": 0.2, "max": 0.6},
	"b": {"key": "hair_saturation", "min": 0.6, "max": 1.0},
}
const EYE_SLIDERS := {
	"a": {"key": "iris_boost", "min": 0.0, "max": 1.0},
	"b": {"key": "iris_saturation", "min": 0.3, "max": 1.6},
}
const BROWS_SLIDERS := {
	"a": {"key": "brows_boost", "min": 0.0, "max": 1.0},
	"b": {"key": "brows_saturation", "min": 0.3, "max": 1.4},
}

# Палитра волос (её же используют брови)
const HAIR_PALETTE := ["2b1d1a", "5a3a28", "8a5a3a", "c9955a", "e8c98a", "f5e6b8",
	"d94a4a", "e87aa0", "c27ad9", "6a7fe8", "4ab5c9", "5cc97a", "b0b0b0", "ffffff"]

# Вкладки: слои (ключ в паспорте + папка) и какой цвет меняет вкладка
const TABS := [
	{"name": "Волосы", "color": "hair_color", "sliders": HAIR_SLIDERS, "layers": [
		{"name": "Длина", "key": "hair_back", "folder": "res://hair/back hair", "none": true},
		{"name": "Допы", "key": "hair_extra", "folder": "res://hair/extra hair", "none": true},
		{"name": "Середина", "key": "hair_mid", "folder": "res://hair/middle hair", "none": false},
		{"name": "Перёд", "key": "hair_front", "folder": "res://hair/front hair", "none": false},
	]},
	{"name": "Кожа", "color": "skin_color", "layers": []},
	{"name": "Глаза", "color": "eye_color", "sliders": EYE_SLIDERS, "lashes": true, "layers": []},
	{"name": "Брови", "color": "brows_color", "sliders": BROWS_SLIDERS, "layers": [
		{"name": "Брови", "key": "brows", "folder": "res://face/brows", "none": true},
	]},
	{"name": "Нос", "color": "nose_color", "layers": [
		{"name": "Нос", "key": "nose", "folder": "res://face/nose", "none": false},
	]},
	{"name": "Губы", "color": "lips_color", "layers": [
		{"name": "Губы", "key": "lips", "folder": "res://face/lips", "none": false},
	]},
	{"name": "Веки", "color": "", "layers": [
		{"name": "Веки", "key": "eyelids", "folder": "res://face/eyelids", "none": true},
	]},
	{"name": "Румянец", "color": "", "layers": [
		{"name": "Румянец", "key": "blush", "folder": "res://face/blush", "none": true},
	]},
]

# Палитры кружочков: ключ цвета -> список hex
const PALETTES := {
	"skin_color": ["ffe3d4", "f8d5c0", "f2c9b0", "e8b896", "d9a07a", "c68863",
		"a8704a", "8d5a3b", "6e432b", "4f2f1f", "b8e0d2", "d6b8f0", "9ec5e8"],
	"hair_color": HAIR_PALETTE,
	"brows_color": HAIR_PALETTE,
	"eye_color": ["5b8fd6", "3a7d44", "7a5230", "4a4a4a", "8a5fc9", "c94a6a", "4ab5c9", "d9a43a"],
	"nose_color": ["f2a7a0", "e8b896", "d9a07a", "c68863", "a8704a", "8d5a3b"],
	"lips_color": ["e0868a", "c9565e", "a83a4a", "f2a7a0", "d98aa8", "8a3a3a", "7a3a6a"],
}

var tab: Dictionary    # открытая вкладка
var layer: Dictionary  # открытый слой
var palette: HFlowContainer
var lashes_btn: Button
var key_a := ""        # ключ первого ползунка на этой вкладке
var key_b := ""        # ключ второго

func _ready():
	color_btn.color_changed.connect(_on_color_changed)
	slider_a.value_changed.connect(func(v): if key_a != "": character.set_value(key_a, v))
	slider_b.value_changed.connect(func(v): if key_b != "": character.set_value(key_b, v))

	# палитра кружочков
	palette = HFlowContainer.new()
	palette.position = palette_pos
	palette.custom_minimum_size = Vector2(palette_width, 100)
	palette.size = Vector2(palette_width, 100)
	palette.add_theme_constant_override("h_separation", 16)
	palette.add_theme_constant_override("v_separation", 16)
	add_child(palette)

	# кнопка ресниц
	lashes_btn = Button.new()
	lashes_btn.toggle_mode = true
	lashes_btn.position = lashes_pos
	lashes_btn.custom_minimum_size = Vector2(300, 90)
	lashes_btn.toggled.connect(_on_lashes_toggled)
	add_child(lashes_btn)

	for t in TABS:
		var b = Button.new()
		b.text = t["name"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 90)
		b.pressed.connect(_show_tab.bind(t))
		tabs_bar.add_child(b)
	_show_tab(TABS[0])

# Открыть вкладку
func _show_tab(t: Dictionary):
	tab = t

	# кнопки слоёв (только если слоёв больше одного)
	for c in layer_bar.get_children():
		c.queue_free()
	if t["layers"].size() > 1:
		for l in t["layers"]:
			var b = Button.new()
			b.text = l["name"]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(_show_layer.bind(l))
			layer_bar.add_child(b)

	# варианты
	if t["layers"].is_empty():
		for c in grid.get_children():
			c.queue_free()
	else:
		_show_layer(t["layers"][0])

	# цвет
	var key = t["color"]
	color_btn.visible = key != ""
	if key != "":
		color_btn.color = Color(character.passport[key])

	# ползунки
	key_a = ""
	key_b = ""
	var s = t.get("sliders", {})
	slider_a.visible = s.has("a")
	slider_b.visible = s.has("b")
	if s.has("a"):
		key_a = _setup_slider(slider_a, s["a"])
	if s.has("b"):
		key_b = _setup_slider(slider_b, s["b"])

	# ресницы
	lashes_btn.visible = t.get("lashes", false)
	if lashes_btn.visible:
		lashes_btn.set_pressed_no_signal(character.passport["lashes"])
		_update_lashes_text()

	_build_palette()

# Настроить ползунок под вкладку, вернуть ключ паспорта
func _setup_slider(sl: Range, cfg: Dictionary) -> String:
	sl.min_value = cfg["min"]
	sl.max_value = cfg["max"]
	sl.step = 0.01
	sl.set_value_no_signal(character.passport[cfg["key"]])
	return cfg["key"]

# Ресницы вкл/выкл
func _on_lashes_toggled(on: bool):
	character.set_value("lashes", on)
	_update_lashes_text()

func _update_lashes_text():
	lashes_btn.text = "Ресницы: вкл" if lashes_btn.button_pressed else "Ресницы: выкл"

# Кружочки с цветами для открытой вкладки
func _build_palette():
	for c in palette.get_children():
		palette.remove_child(c)
		c.queue_free()
	var key = tab["color"]
	palette.visible = PALETTES.has(key)
	if not palette.visible:
		return
	var cur = str(character.passport[key]).to_lower()
	for hex in PALETTES[key]:
		var b = Button.new()
		b.custom_minimum_size = Vector2(circle_size, circle_size)
		b.focus_mode = Control.FOCUS_NONE
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(hex)
		sb.set_corner_radius_all(int(circle_size / 2))
		if hex == cur:
			sb.set_border_width_all(8)
			sb.border_color = Color(0.2, 0.2, 0.2)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_pick_color.bind(hex))
		palette.add_child(b)

# Применить выбранный цвет (кружок или полоска)
func _apply_color(hex: String):
	var key = tab["color"]
	if key == "":
		return
	character.set_value(key, hex)
	if key == "hair_color":
		character.set_value("brows_match_hair", true)   # брови следом за волосами
	elif key == "brows_color":
		character.set_value("brows_match_hair", false)  # у бровей свой цвет

# Нажали кружочек
func _pick_color(hex: String):
	_apply_color(hex)
	color_btn.color = Color(hex)
	_build_palette()

# Показать варианты слоя
func _show_layer(l: Dictionary):
	layer = l
	for c in grid.get_children():
		c.queue_free()
	if l["none"]:
		_add_variant("")
	for file in ResourceLoader.list_directory(l["folder"]):
		if file.ends_with(".png"):
			_add_variant(l["folder"] + "/" + file)

# Одна кнопка-вариант
func _add_variant(path: String):
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(160, 160)
	if path == "":
		btn.text = "нет"
	else:
		btn.icon = load(path)
		btn.expand_icon = true
	btn.pressed.connect(func(): character.set_value(layer["key"], path))
	grid.add_child(btn)

# Свой цвет с полоски
func _on_color_changed(c: Color):
	_apply_color(c.to_html(false))
	_build_palette()

# Сохраняем, когда уходим из редактора
func _exit_tree():
	SaveManager.save_game()
