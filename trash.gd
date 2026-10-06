extends Control

func _ready():
	add_to_group("trash")

# Вернёт true, если предмет удалён
func try_delete(item: Node, touch_pos: Vector2) -> bool:
	if not item.has_meta("item_path"):
		return false
	if not get_global_rect().has_point(touch_pos):
		return false
	item.queue_free()
	SaveManager.request_save()
	return true

func _process(_delta: float) -> void:
	visible = not GameMode.is_life_mode
