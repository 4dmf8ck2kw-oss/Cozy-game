extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	SaveManager.reset_save()
	get_tree().reload_current_scene()
