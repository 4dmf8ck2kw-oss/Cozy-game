extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _process(delta: float) -> void:
	visible = GameMode.is_life_mode

func _on_pressed() -> void:
	if not GameMode.is_life_mode:
		return
	disabled = true
	await get_tree().create_timer(0.4).timeout
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://world.tscn")
