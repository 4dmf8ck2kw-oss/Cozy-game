extends Sprite2D

@export var max_offset := 4.0    # насколько далеко бегает радужка
@export var glance_time := 0.6   # за сколько секунд переводит взгляд
@export var head_tilt := 6.0     # наклон головы в градусах
@export var min_wait := 3.0      # пауза между взглядами (сек)
@export var max_wait := 8.0
@export var min_hold := 0.8      # сколько смотрит в сторону (сек)
@export var max_hold := 2.0

@onready var head: Node2D = get_parent().get_parent().get_parent()  # EyeWhite → Face → Head
@onready var head_base: float = head.rotation

var carrier: Node   # тот, кто её таскает (draggable)
var timer := 2.0
var tween: Tween

func _ready():
	var n = get_parent()
	while n and not "dragging" in n:
		n = n.get_parent()
	carrier = n

func _process(delta):
	if carrier and carrier.dragging:
		timer = 1.0  # пока несут — не поглядывает
		return
	timer -= delta
	if timer <= 0.0:
		timer = randf_range(min_wait, max_wait)
		_glance()

# Посмотреть в сторону → подержать → вернуться прямо
func _glance():
	var target = Vector2.from_angle(randf() * TAU) * max_offset * randf_range(0.5, 1.0)
	var tilt = head_base - deg_to_rad(head_tilt) * target.y / max_offset

	if tween:
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target, glance_time)
	tween.parallel().tween_property(head, "rotation", tilt, glance_time * 1.5)
	tween.tween_interval(randf_range(min_hold, max_hold))
	tween.tween_property(self, "position", Vector2.ZERO, glance_time)
	tween.parallel().tween_property(head, "rotation", head_base, glance_time * 1.5)
