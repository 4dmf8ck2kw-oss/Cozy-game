extends Node

# Central owner for choosing which draggable Area2D receives a touch.
# Keep this deliberately simple: no sort_custom/callback magic, so this script
# remains safe on the project's Godot 4.6 mobile build.
const MAX_HITS: int = 64

func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	if not event.pressed:
		return
	if event.index != 0:
		return
	if GameMode.dragged_object != null:
		return

	var target = _pick_draggable(event.position)
	if target == null:
		return

	target.begin_drag(event.position)
	get_viewport().set_input_as_handled()


func _pick_draggable(screen_pos: Vector2):
	var scene = get_tree().current_scene
	if scene == null:
		return null

	# Convert viewport/screen coordinates to world/canvas coordinates exactly the
	# same way draggable.gd converts touch coordinates during dragging.
	var world_pos: Vector2 = scene.get_canvas_transform().affine_inverse() * screen_pos
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hits = scene.get_world_2d().direct_space_state.intersect_point(query, MAX_HITS)
	var best = null

	for hit in hits:
		var obj = hit.get("collider")
		if obj == null:
			continue
		if not is_instance_valid(obj):
			continue
		if not obj.has_method("begin_drag"):
			continue
		if not obj.has_method("can_start_drag"):
			continue
		if obj is CanvasItem and not obj.visible:
			continue
		if not obj.can_start_drag():
			continue

		if best == null or _candidate_is_better(obj, best):
			best = obj

	return best


func _candidate_is_better(candidate, current) -> bool:
	# Portable decor/characters win over furniture underneath. This fixes the
	# pillow-on-sofa case without changing placement/depth systems yet.
	var candidate_portable: int = 0
	var current_portable: int = 0
	if "moves_in_life" in candidate and candidate.moves_in_life:
		candidate_portable = 1
	if "moves_in_life" in current and current.moves_in_life:
		current_portable = 1
	if candidate_portable != current_portable:
		return candidate_portable > current_portable

	var candidate_z: int = _effective_z(candidate)
	var current_z: int = _effective_z(current)
	if candidate_z != current_z:
		return candidate_z > current_z

	# For equal z, later siblings are drawn later and should receive the touch.
	# The current project keeps competing draggable roots under the same gameplay
	# parent in the cases we are stabilizing.
	if candidate.get_parent() == current.get_parent():
		return candidate.get_index() > current.get_index()

	# Deterministic fallback: do not replace the already selected candidate.
	return false


func _effective_z(item) -> int:
	if not (item is CanvasItem):
		return 0
	var total: int = item.z_index
	if not item.z_as_relative:
		return total

	var parent = item.get_parent()
	while parent is CanvasItem:
		total += parent.z_index
		if not parent.z_as_relative:
			break
		parent = parent.get_parent()
	return total
