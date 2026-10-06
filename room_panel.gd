extends VBoxContainer

const PATTERN_FOLDER := "res://pattern"

# Однотонные стены
const PLAIN := [
	"f5d6d6", "f7e7c6", "dcebd5", "d6e4f0", "e6dcf0", "ffffff",
]

# Цвета пола
const FLOOR := [
	"8a8a8a", "c8b8a8", "a58b74", "7a6a5e", "b7c4b0", "9aa7b8",
]

# Расцветки паттернов: [линии, фон, прожилки]
const SCHEMES := [
	["b88c61", "edd6a8", "fff5db"],  # мёд
	["c9b8a0", "f2ebe0", "ffffff"],  # светлое
	["d49a9a", "f5d6d6", "fff0f0"],  # розовое
	["6b4630", "9c6b48", "c49a72"],  # орех
	["8aa38a", "d5e3cf", "f3f8f0"],  # мятное
	["9a8fb8", "ddd6ee", "f7f4fc"],  # лавандовое
]

@onready var room = get_tree().current_scene.get_node("Background")

var patterns: Array = []      # все паттерны из папки
var current_pattern := ""     # какой паттерн сейчас выбран

func _ready():
	# Паттерны сами берутся из папки
	for file in ResourceLoader.list_directory(PATTERN_FOLDER):
		if file.ends_with(".png"):
			patterns.append(PATTERN_FOLDER + "/" + file)

	current_pattern = room.look["wall_pattern"]
	if current_pattern == "" and not patterns.is_empty():
		current_pattern = patterns[0]

	# Кнопки паттернов: превью в текущей расцветке
	for path in patterns:
		var b = Button.new()
		b.custom_minimum_size = Vector2(80, 80)
		b.icon = load(path)
		b.expand_icon = true
		b.material = room.pattern_mat
		b.pressed.connect(_on_pattern.bind(path))
		$PatternList.add_child(b)

	# Однотонные стены
	for hex in PLAIN:
		var b = _circle(Color(hex), Color(hex).darkened(0.2))
		b.pressed.connect(_on_plain.bind(hex))
		$WallColors.add_child(b)

	# Расцветки паттернов
	for s in SCHEMES:
		var b = _circle(Color(s[1]), Color(s[0]))
		b.pressed.connect(_on_scheme.bind(s))
		$PatternColors.add_child(b)

	# Пол
	for hex in FLOOR:
		var b = _circle(Color(hex), Color(hex).darkened(0.2))
		b.pressed.connect(_on_floor.bind(hex))
		$FloorColors.add_child(b)

# Палитра видна только в режиме строительства
func _process(_delta):
	visible = not GameMode.is_life_mode

# Круглая кнопка
func _circle(fill: Color, border: Color) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	var sb = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(8)
	sb.set_corner_radius_all(40)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	return btn

func _on_pattern(path: String):
	current_pattern = path
	room.set_value("wall_pattern", path)

func _on_plain(hex: String):
	room.set_value("wall_color", hex)
	room.set_value("wall_pattern", "")

func _on_scheme(s: Array):
	room.set_value("wall_dark", s[0])
	room.set_value("wall_mid", s[1])
	room.set_value("wall_light", s[2])
	room.set_value("wall_pattern", current_pattern)

func _on_floor(hex: String):
	room.set_value("floor_color", hex)
