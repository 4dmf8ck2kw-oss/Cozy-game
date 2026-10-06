extends Button
@export_file("*.tscn") var target_scene := "res://node_2d.tscn"

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	disabled = true
	get_tree().change_scene_to_file(target_scene)