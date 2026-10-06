extends Node2D

@export var stiffness := 60.0   # пружинистость: как быстро косы возвращаются вниз
@export var damping := 6.0      # затухание: как быстро перестают качаться
@export var inertia := 0.02     # как сильно отстают, когда персонажа тащат
@export var follow_head := 0.3  # насколько наклоняются вместе с головой (0 — висят строго вниз)
@export var max_angle := 40.0   # максимальный размах в градусах
@export var rotate_amount := 0.3  # 1 — косы качаются целиком от верха, 0 — только гнутся

var angle := 0.0
var speed := 0.0
var rest_rotation := 0.0
var head_rest := 0.0
var last_pos := Vector2.ZERO
var hair_mat: ShaderMaterial

func _ready():
	rest_rotation = global_rotation
	head_rest = get_parent().global_rotation
	last_pos = global_position

func _process(delta):
	if delta <= 0.0:
		return
	var vel = (global_position - last_pos) / delta
	last_pos = global_position
	hair_mat = $"../HairFront".material

	var force = -stiffness * angle - damping * speed + vel.x * inertia
	speed += force * delta
	angle += speed * delta
	var limit = deg_to_rad(max_angle)
	angle = clamp(angle, -limit, limit)

	var head_turn = get_parent().global_rotation - head_rest
	global_rotation = rest_rotation + head_turn * follow_head + angle * rotate_amount
	if hair_mat:
		hair_mat.set_shader_parameter("sway", angle)
