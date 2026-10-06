extends Node2D

# Stylized blob shadow. This is intentionally art-directed rather than physically exact:
# one soft shape under the object, close to the supporting surface.
enum Shape { ELLIPSE, ROUNDED_RECT }

@export var shadow_size := Vector2(160, 18)
@export var color := Color(0.12, 0.10, 0.09, 0.18)
@export var shape := Shape.ELLIPSE

func _ready() -> void:
	show_behind_parent = true
	queue_redraw()

func _ellipse_points(size: Vector2, factor: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a) * size.x * 0.5 * factor, sin(a) * size.y * 0.5 * factor))
	return pts

func _rounded_rect_points(size: Vector2, factor: float) -> PackedVector2Array:
	var half := size * 0.5 * factor
	var radius: float = min(half.y, min(half.x, size.y * 0.45 * factor))
	var pts := PackedVector2Array()
	var centers := [
		Vector2(half.x - radius, -half.y + radius),
		Vector2(half.x - radius, half.y - radius),
		Vector2(-half.x + radius, half.y - radius),
		Vector2(-half.x + radius, -half.y + radius)
	]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for corner in 4:
		for step in 7:
			var a: float = starts[corner] + (PI * 0.5) * float(step) / 6.0
			pts.append(centers[corner] + Vector2(cos(a), sin(a)) * radius)
	return pts

func _points(size: Vector2, factor: float) -> PackedVector2Array:
	if shape == Shape.ROUNDED_RECT:
		return _rounded_rect_points(size, factor)
	return _ellipse_points(size, factor)

func _draw() -> void:
	# Three layers give a soft edge without shaders/realtime lights.
	var outer := Color(color.r, color.g, color.b, color.a * 0.30)
	var middle := Color(color.r, color.g, color.b, color.a * 0.34)
	var inner := Color(color.r, color.g, color.b, color.a * 0.38)
	draw_colored_polygon(_points(shadow_size, 1.00), outer)
	draw_colored_polygon(_points(shadow_size, 0.92), middle)
	draw_colored_polygon(_points(shadow_size, 0.82), inner)
