extends Bone2D

@export var stiffness := 80.0   # пружинистость
@export var damping := 10.0     # затухание
@export var inertia := 0.004    # как сильно отстаёт при движении
@export var max_angle := 25.0   # максимальный размах в градусах

var angle := 0.0
var speed := 0.0
var base_rot := 0.0
var last_written := 0.0
var last_pos := Vector2.ZERO

func _ready():
	process_priority = 100  # работаем ПОСЛЕ AnimationPlayer
	base_rot = rotation
	last_written = rotation
	last_pos = global_position

func _process(delta):
	if delta <= 0.0:
		return
	# если анимация поменяла поворот — это новая поза, качаем от неё
	if not is_equal_approx(rotation, last_written):
		base_rot = rotation

	var vel = (global_position - last_pos) / delta
	last_pos = global_position

	var force = -stiffness * angle - damping * speed + vel.x * inertia
	speed += force * delta
	var limit = deg_to_rad(max_angle)
	angle = clamp(angle + speed * delta, -limit, limit)

	rotation = base_rot + angle
	last_written = rotation
