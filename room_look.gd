extends Node2D

# «Паспорт» комнаты
var look := {
	"wall_pattern": "",      # путь к серому паттерну, "" = однотонная стена
	"wall_color": "f5d6d6",  # цвет однотонной стены
	"wall_dark": "b88c61",   # расцветка паттерна: линии
	"wall_mid": "edd6a8",    # фон
	"wall_light": "fff5db",  # прожилки
	"floor_color": "8a8a8a", # цвет пола
}

@onready var wall = $Wall
@onready var floor_spr = $Floor
var pattern_mat: ShaderMaterial  # материал с шейдером расцветки
var plain_tex: ImageTexture      # белая плитка для однотонной стеныпол: белая картинка того же размера, чтобы цвет был чистым

func _ready():
	pattern_mat = wall.material
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	plain_tex = ImageTexture.create_from_image(img)
	var fsize = floor_spr.texture.get_size()
	var fimg = Image.create(int(fsize.x), int(fsize.y), false, Image.FORMAT_RGBA8)
	fimg.fill(Color.WHITE)
	floor_spr.texture = ImageTexture.create_from_image(fimg)

	if GameMode.room.is_empty():
		look["wall_pattern"] = wall.texture.resource_path if wall.texture else ""
		GameMode.room = look.duplicate()
	else:
		# берём сохранённое, а новые настройки остаются по умолчанию
		for key in GameMode.room:
			look[key] = GameMode.room[key]
	apply_look()

# Применить паспорт к комнате
func apply_look():
	if look["wall_pattern"] != "":
		# паттерн + три цвета расцветки
		wall.texture = load(look["wall_pattern"])
		wall.material = pattern_mat
		pattern_mat.set_shader_parameter("color_dark", Color(look["wall_dark"]))
		pattern_mat.set_shader_parameter("color_mid", Color(look["wall_mid"]))
		pattern_mat.set_shader_parameter("color_light", Color(look["wall_light"]))
		wall.modulate = Color.WHITE
	else:
		# однотонная стена
		wall.texture = plain_tex
		wall.material = null
		wall.modulate = Color(look["wall_color"])

	# пол (self_modulate красит только сам пол, без линии стыка)
	floor_spr.modulate = Color.WHITE
	floor_spr.self_modulate = Color(look["floor_color"])

# Поменять одну вещь
func set_value(key, value):
	look[key] = value
	apply_look()
	GameMode.room = look.duplicate()
	SaveManager.request_save()
