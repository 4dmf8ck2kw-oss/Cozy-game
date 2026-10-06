extends Node

func _ready() -> void:
	var data = SaveManager.load_game()
	SaveManager.apply_save_data(data)

var is_life_mode = true
var dragged_object = null
var passports := {}  # паспорта внешности всех персонажей: {id: паспорт}
var room := {}  # как выглядит комната

func toggle_mode():
	if is_life_mode == false:
		for obj in get_tree().get_nodes_in_group("needs_floor"):
			if not obj.is_placed_ok():
				return
	is_life_mode = not is_life_mode

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_game()
		get_tree().quit()
