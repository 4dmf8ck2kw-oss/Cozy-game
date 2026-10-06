extends Skeleton2D

@export var character_id := "girl1"  # номерок в шкафу паспортов
@export var nose_mid := 0.6          # яркость заливки носа в PNG
@export var nose_line := 0.4         # всё, что темнее, — чистый лайн кожи
@export var nose_tint := 0.35        # 0 = нос цвета кожи, 1 = цвет из вкладки «Нос»
@export var lips_mid := 0.6          # яркость губ в PNG
@export var iris_shine := 0.5        # блеск радужки
@export var skin_mid := 0.45         # яркость заливки тела в PNG
@export var skin_line_point := 0.15  # всё темнее — чистый лайн кожи
@export var skin_line_darken := 0.5  # насколько лайн темнее кожи (0–1)
@export var skin_line_sat := 0.25    # насколько лайн насыщеннее кожи
@export var lift_up := 1.2           # сила осветления ползунком яркости
@export var lift_down := 0.7         # сила затемнения ползунком яркости

# «Паспорт» внешности
var passport := {
	"hair_back": "",
	"hair_extra": "",
	"hair_mid": "",
	"hair_front": "",
	"hair_color": "ffffff",
	"hair_shine": 0.5,
	"hair_saturation": 0.7,
	"brows_match_hair": true,   # брови цвета волос
	"brows_color": "4a3527",    # свой цвет бровей
	"brows_boost": 0.6,         # яркость бровей (0.5 = без изменений)
	"brows_saturation": 0.8,    # насыщенность бровей
	"brows": "",
	"nose": "",
	"lips": "",
	"eyelids": "",
	"blush": "",
	"nose_color": "f2a7a0",
	"lips_color": "e0868a",
	"eye_color": "5b8fd6",
	"iris_boost": 0.6,          # яркость радужки
	"iris_saturation": 1.0,     # насыщенность радужки
	"lashes": true,             # ресницы включены
	"skin_color": "f2c9b0",
	"skin_line": "8b4a3c",      # считается из цвета кожи сам
}

# Слои волос
const HAIR_NODES := {
	"hair_back": "Torso/HairBack",
	"hair_extra": "Torso/Head/BraidPivot/HairExtra",
	"hair_mid": "Torso/Head/HairMid",
	"hair_front": "Torso/Head/HairFront",
}
# Черты лица (одна картинка на вариант)
const FACE_NODES := {
	"brows": "Torso/Head/Face/Brows",
	"nose": "Torso/Head/Face/Nose",
	"lips": "Torso/Head/Face/Lips",
	"eyelids": "Torso/Head/Face/EyeLids",
	"blush": "Torso/Head/HeadSprite/Blush",
}
const IRIS := "Torso/Head/Face/EyeWhite/EyeIris"
const LASHES := "Torso/Head/Face/EyeLashes"
const PATTERN_SHADER := "res://shaders/pattern_color.gdshader"
const HAIR_SHADER := "res://shaders/hair_color.gdshader"
const SKIN_SHADER := "res://shaders/skin_color.gdshader"

var hair_mat: ShaderMaterial   # общий материал волос
var brows_mat: ShaderMaterial  # свой материал бровей
var nose_mat: ShaderMaterial
var lips_mat: ShaderMaterial
var iris_mat: ShaderMaterial
var skin_mat: ShaderMaterial   # общий материал кожи

func _ready():
	# волосы: один общий материал на все слои
	hair_mat = get_node(HAIR_NODES["hair_front"]).material
	for key in HAIR_NODES:
		get_node(HAIR_NODES[key]).material = hair_mat
	brows_mat = hair_mat.duplicate()

	# нос и губы: шейдер на три цвета; радужка: шейдер волос (сохраняет оттенки)
	nose_mat = _new_mat(FACE_NODES["nose"], PATTERN_SHADER)
	lips_mat = _new_mat(FACE_NODES["lips"], PATTERN_SHADER)
	iris_mat = _new_mat(IRIS, HAIR_SHADER)

	# кожа: один материал на все узлы группы skin
	skin_mat = ShaderMaterial.new()
	skin_mat.shader = load(SKIN_SHADER)
	for n in find_children("*", "CanvasItem", true, false):
		if n.is_in_group("skin") or n.is_in_group("Skin"):
			n.material = skin_mat

	# сначала то, что стоит в сцене, поверх — сохранённое
	read_from_scene()
	if GameMode.passports.has(character_id):
		var saved = GameMode.passports[character_id]
		for key in saved:
			passport[key] = saved[key]
	apply_passport()
	GameMode.passports[character_id] = passport.duplicate()

# Создать материал с нужным шейдером и надеть на узел
func _new_mat(node_path: String, shader_path: String) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = load(shader_path)
	get_node(node_path).material = mat
	return mat

# Записать в паспорт то, что сейчас стоит в сцене
func read_from_scene():
	for nodes in [HAIR_NODES, FACE_NODES]:
		for key in nodes:
			var spr = get_node(nodes[key])
			passport[key] = spr.texture.resource_path if spr.texture else ""
	passport["hair_color"] = hair_mat.get_shader_parameter("hair_color").to_html(false)
	passport["hair_shine"] = hair_mat.get_shader_parameter("shine")
	passport["hair_saturation"] = hair_mat.get_shader_parameter("saturation")

# Лайн кожи: тот же оттенок, но темнее и насыщеннее
func _skin_line(c: Color) -> Color:
	var s = clampf(c.s * 1.2 + skin_line_sat, 0.0, 1.0)
	var v = c.v * (1.0 - skin_line_darken)
	return Color.from_hsv(c.h, s, v)

# Ползунок яркости: 0.5 = без изменений, вправо светлее, влево темнее
func _lift(c: Color, v: float) -> Color:
	if v >= 0.5:
		return c.lerp(Color.WHITE, (v - 0.5) * lift_up)
	return c.darkened((0.5 - v) * lift_down)

# Надеть на персонажа всё, что написано в паспорте
func apply_passport():
	for nodes in [HAIR_NODES, FACE_NODES]:
		for key in nodes:
			var path = passport[key]
			get_node(nodes[key]).texture = load(path) if path != "" else null

	# ресницы
	get_node(LASHES).visible = passport["lashes"]

	# волосы
	hair_mat.set_shader_parameter("hair_color", Color(passport["hair_color"]))
	hair_mat.set_shader_parameter("shine", passport["hair_shine"])
	hair_mat.set_shader_parameter("saturation", passport["hair_saturation"])

	# брови: цвет волос (автоматически) или свой, плюс яркость и насыщенность
	var brows = get_node(FACE_NODES["brows"])
	var brows_c = Color(passport["hair_color"]) if passport["brows_match_hair"] else Color(passport["brows_color"])
	brows_mat.set_shader_parameter("hair_color", _lift(brows_c, passport["brows_boost"]))
	brows_mat.set_shader_parameter("shine", passport["hair_shine"])
	brows_mat.set_shader_parameter("saturation", passport["brows_saturation"])
	brows.material = brows_mat

	# радужка: ползунок яркости сдвигает сам цвет
	iris_mat.set_shader_parameter("hair_color", _lift(Color(passport["eye_color"]), passport["iris_boost"]))
	iris_mat.set_shader_parameter("light_boost", 0.6)
	iris_mat.set_shader_parameter("shine", iris_shine)
	iris_mat.set_shader_parameter("saturation", passport["iris_saturation"])

	# кожа: лайн считается из цвета кожи
	var skin_c = Color(passport["skin_color"])
	var skin_l = _skin_line(skin_c)
	passport["skin_line"] = skin_l.to_html(false)
	_paint(skin_mat, skin_l, skin_c, skin_mid, skin_line_point)

	# нос: заливка от цвета кожи с лёгким подмесом, лайн как у кожи
	var nose_c = skin_c.darkened(0.06).lerp(Color(passport["nose_color"]), nose_tint)
	_paint(nose_mat, skin_l, nose_c, nose_mid, nose_line)

	# губы: темнее цвета губ
	var lips_c = Color(passport["lips_color"])
	_paint(lips_mat, lips_c.darkened(0.35), lips_c, lips_mid, 0.0)

# Покрасить часть: тёмный / основной / светлый
func _paint(mat: ShaderMaterial, dark: Color, main: Color, mid: float, line: float):
	mat.set_shader_parameter("color_dark", dark)
	mat.set_shader_parameter("color_mid", main)
	mat.set_shader_parameter("color_light", main.lightened(0.3))
	mat.set_shader_parameter("mid_point", mid)
	mat.set_shader_parameter("line_point", line)

# Поменять одну вещь и сразу применить
func set_value(key, value):
	passport[key] = value
	apply_passport()
	GameMode.passports[character_id] = passport.duplicate()
