extends Camera2D

@export var room_left: float = 0.0
@export var room_right: float = 3840.0
@export var edge_zone: float = 120.0
@export var edge_speed: float = 900.0

var edge_scrolling: bool = false


func _ready() -> void:
	add_to_group("main_camera")
	_clamp_camera()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.index == 0:
		var obj = GameMode.dragged_object
		if obj == null or not is_instance_valid(obj):
			var scale_x = get_canvas_transform().x.x
			position.x -= event.relative.x / scale_x
			_clamp_camera()


func _process(delta: float) -> void:
	edge_scrolling = false
	var obj = GameMode.dragged_object
	if obj == null or not is_instance_valid(obj):
		return
	if not ("last_touch_pos" in obj):
		return
	var finger_x = obj.last_touch_pos.x
	var screen_w = get_viewport_rect().size.x
	var dir = 0
	if finger_x < edge_zone:
		dir = -1
	elif finger_x > screen_w - edge_zone:
		dir = 1
	if dir != 0:
		var old_x = position.x
		position.x += dir * edge_speed * delta
		_clamp_camera()
		edge_scrolling = position.x != old_x


func _clamp_camera() -> void:
	var scale_x = get_canvas_transform().x.x
	if scale_x == 0:
		return
	var view_w = get_viewport_rect().size.x / scale_x
	var left_offset = 0.0 if anchor_mode == ANCHOR_MODE_FIXED_TOP_LEFT else view_w / 2.0
	var min_x = room_left + left_offset
	var max_x = room_right - view_w + left_offset
	if max_x < min_x:
		max_x = min_x
	position.x = clamp(position.x, min_x, max_x)
