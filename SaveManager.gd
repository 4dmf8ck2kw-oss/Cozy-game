extends Node

const SAVE_PATH := "user://savegame.json"
const SAVE_DELAY := 2.0

var _save_timer: Timer

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.one_shot = true
	_save_timer.timeout.connect(save_game)
	add_child(_save_timer)
	_load_passports()

func request_save() -> void:
	_save_timer.start()

func save_game() -> void:
	# Берём старое сохранение, чтобы ничего не потерять
	var data := load_game()

	# Объекты обновляем, только если они есть в этой сцене (в комнате)
	var saveable_nodes = get_tree().get_nodes_in_group("saveable")
	if not saveable_nodes.is_empty():
		var objects := {}
		for obj in saveable_nodes:
			var entry := {
				"pos_x": obj.global_position.x,
				"pos_y": obj.global_position.y,
				"parent_path": str(obj.get_parent().get_path())
			}
			if obj.has_meta("item_path"):
				entry["item_path"] = obj.get_meta("item_path")
			objects[obj.name] = entry
		data["objects"] = objects

	# Паспорта внешности и вид комнаты сохраняем всегда
	data["passports"] = GameMode.passports
	data["room"] = GameMode.room

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("Игра сохранена: ", SAVE_PATH)

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("Файл сохранения не найден.")
		return {}

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		print("Ошибка чтения сохранения.")
		return {}

	print("Игра загружена.")
	return json.data

func apply_save_data(data: Dictionary) -> void:
	if not data.has("objects"):
		return
	# ждём кадр, чтобы новая сцена стала текущей и все узлы создались
	await get_tree().process_frame
	var root = get_tree().current_scene
	if root == null:
		return
	var in_room = not get_tree().get_nodes_in_group("saveable").is_empty()
	var objects = data["objects"]
	var root_path = str(root.get_path())

	# Сначала мебель (то, что стоит само по себе), потом то, что на ней
	for pass_attached in [false, true]:
		for obj_name in objects.keys():
			var obj_data = objects[obj_name]
			var is_attached = obj_data["parent_path"] != root_path
			if is_attached != pass_attached:
				continue

			var obj = get_tree().root.find_child(obj_name, true, false)

			# предмета нет в сцене, но он из каталога: создаём заново
			if obj == null and in_room and obj_data.has("item_path"):
				var path: String = obj_data["item_path"]
				if ResourceLoader.exists(path):
					var item_data: ItemData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
					obj = ItemBuilder.spawn(item_data, root,
						Vector2(obj_data["pos_x"], obj_data["pos_y"]), path)
					obj.name = obj_name
			if obj == null:
				continue

			var target_parent = get_node_or_null(obj_data["parent_path"])
			if target_parent and obj.get_parent() != target_parent:
				obj.reparent(target_parent, true)

			obj.global_position = Vector2(obj_data["pos_x"], obj_data["pos_y"])
			if obj.has_method("restore_after_load"):
				obj.restore_after_load()

func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	print("Сохранение удалено.")

func _load_passports() -> void:
	var data = load_game()
	if data.has("passports"):
		GameMode.passports = data["passports"]
	if data.has("room"):
		GameMode.room = data["room"]
