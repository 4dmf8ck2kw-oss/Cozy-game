extends Area2D

@export var moves_in_life: bool = true
@export var moves_in_build: bool = true

@export var falls: bool = false
@export var fall_only_in_life_mode: bool = true
@export var fall_speed: float = 700.0
@export var floor_y: float = 720.0

@export var needs_placement: bool = false
@export var checks_overlap: bool = false
@export var overlap_group: String = "furniture"
@export var rests_on_furniture: bool = false
@export var uses_zone_placement: bool = false
@export var rest_zone_min_y: float = 0.0
@export var rest_zone_max_y: float = 0.0
@export var decor_z_index: int = 0
@export var is_character: bool = false
@export var max_characters: int = 0
@export var seat_margin: float = 40.0

@export var hide_in_build_mode: bool = false
@export var clamp_to_screen: bool = false
@export var screen_margin: float = 250.0

const ZONE_GROUP := "placement_zone"
const DROP_MARGIN := 40.0   # насколько выше зоны можно отпустить, чтобы прилипло

var original_parent: Node = null
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var last_drag_time: float = 0.0
var drag_z_index: int = 1000

var touching: Array = []
var touching_zones: Array = []
var sit_tween: Tween = null
var is_seated: bool = false
var preview_sit: bool = false
var last_touch_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	original_parent = get_tree().current_scene
	add_to_group("saveable")

	if uses_zone_placement:
		get_parent().call_deferred("move_child", self, 1)

	if needs_placement:
		add_to_group("needs_floor")
	if checks_overlap:
		add_to_group(overlap_group)

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if decor_z_index != 0:
		z_index = decor_z_index

func _on_area_entered(other: Area2D) -> void:
	if other.is_in_group(overlap_group):
		touching.append(other)
	if other.is_in_group(ZONE_GROUP):
		touching_zones.append(other)

func _on_area_exited(other: Area2D) -> void:
	touching.erase(other)
	touching_zones.erase(other)


func _foot_y() -> float:
	var fp = get_node_or_null("FootPoint")
	return fp.global_position.y if fp else global_position.y

func _foot_offset() -> float:
	var fp = get_node_or_null("FootPoint")
	return (fp.global_position.y - global_position.y) if fp else 0.0

# Нижний край предмета (по зоне касания)
func _bottom_y() -> float:
	var cs = get_node_or_null("CollisionShape2D")
	if cs and cs.shape is RectangleShape2D:
		return cs.global_position.y + cs.shape.size.y * cs.global_scale.y / 2.0
	return _foot_y()

# Порядок отрисовки: у кого нижний край выше, тот дальше от зрителя
func _sort_depth() -> void:
	if uses_zone_placement:
		return
	var parent = get_parent()
	if parent != original_parent:
		return
	var my_bottom = _bottom_y()
	var first_in_front := -1
	var last_behind := -1
	for other in parent.get_children():
		if other == self or not other.has_method("_sort_depth"):
			continue
		if other.uses_zone_placement:
			continue
		var i = other.get_index()
		if other._bottom_y() > my_bottom:
			if first_in_front == -1 or i < first_in_front:
				first_in_front = i
		else:
			if i > last_behind:
				last_behind = i
	if last_behind != -1 and get_index() < last_behind:
		parent.move_child(self, last_behind)
	if first_in_front != -1 and get_index() > first_in_front:
		parent.move_child(self, first_in_front)

func _get_zone_range(zone: Area2D):
	var shape_node = zone.get_node_or_null("CollisionShape2D")
	if shape_node == null or shape_node.shape == null:
		return null
	if shape_node.shape is RectangleShape2D:
		var half = (shape_node.shape.size.y * shape_node.global_scale.y) / 2.0
		return [shape_node.global_position.y - half, shape_node.global_position.y + half]
	return [shape_node.global_position.y, shape_node.global_position.y]

# Высота, на которой предмет стоит на зоне (у полки это верхний край)
func _zone_rest_y(zone: Area2D) -> float:
	var r = _get_zone_range(zone)
	if r == null:
		return _floor_target_y()
	var frac: float = zone.get_meta("rest_frac", 0.0)
	return r[0] + (r[1] - r[0]) * frac

func _current_zone() -> Area2D:
	if touching_zones.size() > 0:
		return touching_zones[0]
	var fp = get_node_or_null("FootPoint")
	if fp == null:
		return null
	var p: Vector2 = fp.global_position
	for z in get_tree().get_nodes_in_group(ZONE_GROUP):
		if not (z is Area2D) or self.is_ancestor_of(z):
			continue
		var cs = z.get_node_or_null("CollisionShape2D")
		if cs == null or not (cs.shape is RectangleShape2D):
			continue
		var half: Vector2 = cs.shape.size * cs.global_scale / 2.0
		var c: Vector2 = cs.global_position
		if abs(p.x - c.x) <= half.x and p.y >= c.y - half.y - DROP_MARGIN and p.y <= c.y + half.y:
			return z
	return null


func _floor_target_y() -> float:
	if touching.size() > 0:
		var obj = touching[0]
		if not ("dragging" in obj and obj.dragging):
			var fe = obj.get_node_or_null("FloorEdge")
			if fe:
				return fe.global_position.y
	return _get_floor_y()

func _get_floor_y() -> float:
	var seam = get_tree().get_first_node_in_group("floor_seam")
	if seam:
		return seam.global_position.y
	return floor_y

func _process(delta: float) -> void:
	var cam = get_tree().get_first_node_in_group("main_camera")
	var cam_scrolling = cam != null and cam.edge_scrolling
	if dragging and not cam_scrolling and Time.get_ticks_msec() - last_drag_time > 250:
		GameMode.dragged_object = null
		dragging = false
		_drop()
	if dragging:
		global_position = get_canvas_transform().affine_inverse() * last_touch_pos + drag_offset

	if dragging and is_character:
		var want_sit = _seat_under_hips() != null
		if want_sit != preview_sit:
			preview_sit = want_sit
			_set_pose("sit" if want_sit else "stand")

	if hide_in_build_mode:
		visible = GameMode.is_life_mode

	var attached = (rests_on_furniture and get_parent() != original_parent) or is_seated

	if falls and not dragging and not attached:
		var should_fall = not fall_only_in_life_mode or GameMode.is_life_mode
		if should_fall:
			var zone = null
			if rests_on_furniture and not is_character:
				var candidate = _current_zone()
				if candidate:
					var range_c = _get_zone_range(candidate)
					if range_c != null and _foot_y() <= range_c[1] + 5.0:
						zone = candidate
			var target_y: float
			if zone:
				target_y = _zone_rest_y(zone)
			else:
				target_y = _floor_target_y()

			var foot_y = _foot_y()
			var bouncing = bounce_tween != null and bounce_tween.is_running()
			if foot_y < target_y and not bouncing:
				var move = min(fall_speed * delta, target_y - foot_y)
				global_position.y += move
				foot_y += move
				was_falling = true
			elif was_falling and not bouncing:
				was_falling = false
				_sort_depth()
				_bounce()


			if zone and foot_y >= target_y - 0.5:
				reparent(zone.get_parent(), true)
				_set_pose("sit")

	if clamp_to_screen:
		var vis = get_canvas_transform().affine_inverse() * get_viewport_rect()
		global_position.y = clamp(global_position.y, vis.position.y + screen_margin, vis.end.y - screen_margin)

	if needs_placement:
		var resting_ok = rests_on_furniture and touching_zones.size() > 0
		var bad_spot = not attached and not is_position_ok() and not resting_ok
		modulate = Color(1, 0.4, 0.4) if (not GameMode.is_life_mode and bad_spot) else Color(1, 1, 1)


func can_start_drag() -> bool:
	return (GameMode.is_life_mode and moves_in_life) or (not GameMode.is_life_mode and moves_in_build)

# Drag start is owned by TouchResolver. Keeping it here means the resolver decides
# WHAT was touched, while this object still owns HOW it begins dragging.
func begin_drag(screen_pos: Vector2) -> void:
	if not can_start_drag():
		return
	if GameMode.dragged_object != null:
		return
	if get_parent() != original_parent:
		reparent(original_parent, true)
	GameMode.dragged_object = self
	if not uses_zone_placement:
		get_parent().move_child(self, -1)
	dragging = true
	_set_pose("stand")
	is_seated = false
	preview_sit = false
	if sit_tween:
		sit_tween.kill()
	drag_offset = global_position - get_canvas_transform().affine_inverse() * screen_pos
	last_touch_pos = screen_pos
	last_drag_time = Time.get_ticks_msec()
	z_index = drag_z_index


func _input(event: InputEvent) -> void:
	if not dragging:
		return

	if event is InputEventScreenTouch and (not event.pressed or event.is_canceled()):
		dragging = false
		GameMode.dragged_object = null
		_drop()

	elif event is InputEventScreenDrag:
		global_position = get_canvas_transform().affine_inverse() * event.position + drag_offset
		last_touch_pos = event.position
		last_drag_time = Time.get_ticks_msec()


func _drop() -> void:
	var trash = get_tree().get_first_node_in_group("trash")
	if trash and trash.try_delete(self, last_touch_pos):
		return
	z_index = decor_z_index
	if is_character:
		var seat = _seat_under_hips()
		if seat:
			reparent(seat.get_parent(), true)
			_sit_down(seat)
		else:
			preview_sit = false
			_set_pose("stand")
	elif rests_on_furniture:
		var zone = _current_zone()
		if zone:
			var range_y = _get_zone_range(zone)
			if range_y != null:
				var foot_y = _foot_y()
				if foot_y >= range_y[0] - DROP_MARGIN and foot_y <= range_y[1]:
					# сразу встаём на нужную высоту и садимся на мебель
					global_position.y += clamp(foot_y, range_y[0], range_y[1]) - foot_y
					reparent(zone.get_parent(), true)
	_sort_depth()
	SaveManager.request_save()


func is_position_ok() -> bool:
	if uses_zone_placement:
		return position.y >= rest_zone_min_y and position.y <= rest_zone_max_y
	return position.y >= _get_floor_y()

func is_placed_ok() -> bool:
	if not needs_placement:
		return true
	var resting_ok = rests_on_furniture and touching_zones.size() > 0
	return is_position_ok() or resting_ok


func _set_pose(pose_name: String, blend: float = 0.2) -> void:
	if not is_character:
		return
	var anim = find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation(pose_name):
		anim.play(pose_name, blend)

func _zone_has_room(zone: Area2D) -> bool:
	if not is_character:
		return true
	var furniture = zone.get_parent()
	var limit = furniture.get("max_characters")
	if limit == null or limit <= 0:
		return true
	var count = 0
	for child in furniture.get_children():
		if child != self and child.get("is_character") == true:
			count += 1
	return count < limit

func _seat_under_hips() -> Area2D:
	if not rests_on_furniture:
		return null
	var sp = get_node_or_null("SitPoint")
	if sp == null:
		return null
	var p = sp.global_position
	for zone in touching_zones:
		if not zone.name.begins_with("SeatZone"):
			continue
		var shape_node = zone.get_node_or_null("CollisionShape2D")
		if shape_node == null or not (shape_node.shape is RectangleShape2D):
			continue
		var size = shape_node.shape.size * shape_node.global_scale
		var c = shape_node.global_position
		var inside_x = abs(p.x - c.x) <= size.x / 2.0
		var inside_y = abs(p.y - c.y) <= size.y / 2.0 + seat_margin
		if inside_x and inside_y and _zone_has_room(zone):
			return zone
	return null

func _sit_down(zone: Area2D) -> void:
	get_parent().move_child(self, -1)  # сидящий рисуется поверх подушки
	if is_seated:
		return
	_set_pose("sit")
	is_seated = true
	preview_sit = false
	var range_y = _get_zone_range(zone)
	var sp = get_node_or_null("SitPoint")
	if range_y == null or sp == null:
		return
	var target_y = global_position.y + range_y[0] - sp.global_position.y
	if sit_tween:
		sit_tween.kill()
	sit_tween = create_tween()
	sit_tween.tween_property(self, "global_position:y", target_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func restore_after_load() -> void:
	if is_character and get_parent() != get_tree().current_scene:
		is_seated = true
		_set_pose("sit", 0.0)

var bounce_tween: Tween = null
var was_falling := false

# Маленький подскок при приземлении
func _bounce():
	if is_character:
		return
	if bounce_tween:
		bounce_tween.kill()
	var y = global_position.y
	bounce_tween = create_tween()
	bounce_tween.tween_property(self, "global_position:y", y - 15, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(self, "global_position:y", y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
