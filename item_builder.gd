class_name ItemBuilder
extends RefCounted

const SCENE := "res://item.tscn"
const SHADOW_PATH := "res://shadow.gd"

static func _make_shape(kind: int, size: Vector2) -> Shape2D:
	match kind:
		ItemData.ZoneShape.CIRCLE:
			var c := CircleShape2D.new()
			c.radius = max(size.x, size.y) / 2.0
			return c
		ItemData.ZoneShape.CAPSULE:
			var cap := CapsuleShape2D.new()
			cap.radius = min(size.x, size.y) / 2.0
			cap.height = max(size.x, size.y)
			return cap
		_:
			var r := RectangleShape2D.new()
			r.size = size
			return r

# Прямоугольник реально нарисованной (непрозрачной) части PNG в локальных
# координатах Item. Это не даёт прозрачным полям PNG сдвигать зоны и тени.
static func _visible_rect(texture: Texture2D, sc: float) -> Rect2:
	var tex_size: Vector2 = texture.get_size()
	var used_pos := Vector2.ZERO
	var used_size := tex_size

	var img := texture.get_image()
	if img != null and not img.is_empty():
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			used_pos = Vector2(used.position)
			used_size = Vector2(used.size)

	var top_left := (used_pos - tex_size / 2.0) * sc
	return Rect2(top_left, used_size * sc)

# Перевод относительной точки (x: -0.5..0.5, y: 0..1) в локальные координаты Item.
static func _point_in_visible_rect(rect: Rect2, p: Vector2) -> Vector2:
	return Vector2(
		rect.position.x + rect.size.x * (0.5 + p.x),
		rect.position.y + rect.size.y * p.y
	)


# Finds where the artwork actually touches its supporting surface.
# We inspect a shallow band at the bottom of the visible pixels, project opaque pixels
# onto X, then turn contiguous runs into contact-shadow lobes. This means table legs
# cast small contact shadows while a lampshade does not create a giant oval.
static func _contact_shadow_lobes(texture: Texture2D, sc: float, visible_rect: Rect2) -> Array:
	var result: Array = []
	var img := texture.get_image()
	if img == null or img.is_empty():
		return result
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return result

	# Perspective furniture often has several feet at slightly different Y values.
	# Looking only at the final scanline misses all but the lowest foot, so inspect a
	# shallow bottom band and remember the lowest opaque pixel in every X column.
	var band_h: int = maxi(4, int(ceil(float(used.size.y) * 0.14)))
	var y0: int = used.position.y + used.size.y - band_h
	var bottom_y: int = used.position.y + used.size.y - 1
	var contact_y := PackedInt32Array()
	contact_y.resize(used.size.x)
	contact_y.fill(-1)
	for ix in used.size.x:
		var px := used.position.x + ix
		for py in range(bottom_y, y0 - 1, -1):
			if img.get_pixel(px, py).a > 0.16:
				contact_y[ix] = py
				break

	# Merge only very small anti-aliasing gaps. Real gaps between legs stay separate.
	var gap_limit: int = maxi(1, int(round(float(used.size.x) * 0.010)))
	var x := 0
	while x < contact_y.size():
		if contact_y[x] < 0:
			x += 1
			continue
		var start := x
		var last_opaque := x
		var sum_y := 0.0
		var samples := 0
		var gap := 0
		while x < contact_y.size():
			if contact_y[x] >= 0:
				last_opaque = x
				sum_y += float(contact_y[x])
				samples += 1
				gap = 0
			else:
				gap += 1
				if gap > gap_limit:
					break
			x += 1
		var run_w: int = last_opaque - start + 1
		if run_w >= 2 and samples > 0:
			var local_left: float = visible_rect.position.x + float(start) * sc
			var local_w: float = float(run_w) * sc
			var pad: float = clamp(local_w * 0.30, 4.0, 14.0)
			var center_x: float = local_left + local_w * 0.5
			var avg_y: float = sum_y / float(samples)
			var relative_y: float = (avg_y - float(bottom_y)) * sc + 1.5
			var w: float = local_w + pad * 2.0
			var h: float = clamp(w * 0.13, 4.0, 9.0)
			result.append(Rect2(Vector2(center_x, relative_y), Vector2(w, h)))
	return result

# Собрать предмет из ресурса и положить в parent.
static func spawn(data: ItemData, parent: Node, pos = null, path: String = "", scale_override: float = 0.0) -> Node2D:
	if path == "":
		path = data.resource_path
	var sc: float = scale_override if scale_override > 0.0 else data.sprite_scale

	var item: Node2D = load(SCENE).instantiate()
	item.name = path.get_file().get_basename() + "_" + str(randi() % 1000000)
	item.set_meta("item_path", path)
	parent.add_child(item)

	var visible_rect := _visible_rect(data.texture, sc)
	var visible_center := visible_rect.get_center()
	var visible_size := visible_rect.size

	var spr: Sprite2D = item.get_node("Sprite2D")
	spr.texture = data.texture
	spr.scale = Vector2.ONE * sc

	# Коллизия и точка пола соответствуют самому рисунку, а не прозрачному холсту PNG.
	var shape := RectangleShape2D.new()
	shape.size = visible_size
	var main_col: CollisionShape2D = item.get_node("CollisionShape2D")
	main_col.shape = shape
	main_col.position = visible_center

	item.get_node("FootPoint").position = Vector2(
		visible_center.x,
		visible_rect.position.y + visible_rect.size.y
	)

	# Зона столешницы.
	# ВАЖНО: placement_zone — только дочерняя PlacementZone. Сам Item в эту группу не входит.
	var zone: Area2D = item.get_node_or_null("PlacementZone")
	if zone:
		zone.input_pickable = false
		if data.can_hold:
			var zsize := Vector2(visible_size.x * data.hold_size.x, visible_size.y * data.hold_size.y)
			var zcol: CollisionShape2D = zone.get_node("CollisionShape2D")
			zcol.shape = _make_shape(data.hold_shape, zsize)
			zone.position = Vector2.ZERO
			zcol.position = _point_in_visible_rect(visible_rect, data.hold_pos)
			zone.set_meta("rest_frac", data.hold_rest)
		else:
			zone.queue_free()

	# Зона сиденья создаётся только для предметов, у которых can_sit = true.
	# Раньше поля seat_* были в ItemData, но сама зона вообще не создавалась.
	if data.can_sit:
		var seat := Area2D.new()
		seat.name = "SeatZone"
		seat.input_pickable = false
		var seat_col := CollisionShape2D.new()
		var seat_size := Vector2(visible_size.x * data.seat_size.x, visible_size.y * data.seat_size.y)
		seat_col.shape = _make_shape(data.seat_shape, seat_size)
		seat_col.position = _point_in_visible_rect(visible_rect, data.seat_pos)
		seat.add_child(seat_col)
		item.add_child(seat)
		seat.add_to_group("placement_zone")

	# Stylized blob shadow: one soft shape directly under the object.
	# Do NOT derive it from individual feet; that produced tiny disconnected marks.
	if data.has_shadow and ResourceLoader.exists(SHADOW_PATH):
		var shadow: Node2D = Node2D.new()
		shadow.name = "Shadow"
		shadow.set_script(load(SHADOW_PATH))
		var visible_bottom := visible_rect.position.y + visible_rect.size.y
		item.add_child(shadow)
		item.move_child(shadow, 0)

		var auto_size: Vector2
		if data.kind == ItemData.Kind.FURNITURE:
			auto_size = Vector2(clamp(visible_size.x * 1.16, 130.0, 650.0), clamp(visible_size.x * 0.30, 52.0, 125.0))
		else:
			auto_size = Vector2(clamp(visible_size.x * 1.10, 34.0, 190.0), clamp(visible_size.x * 0.34, 18.0, 52.0))
		shadow.shadow_size = data.shadow_size if data.shadow_size != Vector2.ZERO else auto_size
		# Pull the blob upward into the footprint instead of centering it below the feet.
		# About 45% of its height is lifted above the lowest visible pixel; this keeps
		# the lower soft edge at floor contact while filling the space under the object.
		shadow.position = Vector2(visible_center.x, visible_bottom - shadow.shadow_size.y * 0.45) + data.shadow_offset

		var chosen_shape: int = data.shadow_shape
		if chosen_shape == ItemData.ShadowShape.AUTO:
			# Wide furniture reads better as a soft rounded rectangle; compact decor as an oval.
			chosen_shape = ItemData.ShadowShape.ROUNDED_RECT if data.kind == ItemData.Kind.FURNITURE and visible_size.x > visible_size.y * 1.35 else ItemData.ShadowShape.ELLIPSE
		shadow.shape = 1 if chosen_shape == ItemData.ShadowShape.ROUNDED_RECT else 0

	# мебель: висит и краснеет; декор: падает и двигается в жизни
	var furniture := data.kind == ItemData.Kind.FURNITURE
	item.needs_placement = furniture
	item.checks_overlap = furniture
	item.moves_in_life = not furniture
	item.falls = not furniture
	item.fall_only_in_life_mode = false
	# All generic DECOR can rest on compatible furniture surfaces.
	# Previously this flag was only set manually on old scene-authored decor,
	# so ItemBuilder decor (e.g. the lamp) could detect a PlacementZone but
	# would never use/reparent to it.
	item.rests_on_furniture = not furniture

	if pos == null:
		var vp = parent.get_viewport()
		pos = vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size / 2.0)
	item.global_position = pos
	return item
