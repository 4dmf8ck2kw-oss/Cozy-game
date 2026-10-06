extends Button

const PATH := "res://items/table_lamp_01.tres"

func _process(_delta: float) -> void:
	visible = not GameMode.is_life_mode

func _pressed() -> void:
	var data: ItemData = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	ItemBuilder.spawn(data, get_tree().current_scene)
	SaveManager.request_save()
