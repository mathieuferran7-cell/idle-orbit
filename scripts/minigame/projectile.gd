class_name MinigameProjectile
extends Area2D

var speed: float = 600.0
var damage: int = 1
var direction: Vector2 = Vector2.ZERO
var _lifetime: float = 3.0
var _screen_size: Vector2

func setup(start_pos: Vector2, target_pos: Vector2, spd: float, dmg: int) -> void:
	position = start_pos
	direction = (target_pos - start_pos).normalized()
	speed = spd
	damage = dmg

	var shape := CircleShape2D.new()
	shape.radius = 5.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	collision_layer = 4
	collision_mask = 2
	area_entered.connect(_on_area_entered)
	_create_trail()

func _ready() -> void:
	_screen_size = get_viewport().get_visible_rect().size

func _process(delta: float) -> void:
	if _screen_size == Vector2.ZERO:
		_screen_size = get_viewport().get_visible_rect().size
	position += direction * speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0 or position.x < -100 or position.x > _screen_size.x + 100 or position.y < -100 or position.y > _screen_size.y + 100:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()

func _create_trail() -> void:
	var trail := CPUParticles2D.new()
	trail.name = "Trail"
	trail.emitting = true
	trail.amount = 6
	trail.lifetime = 0.25
	trail.local_coords = false
	trail.direction = Vector2.ZERO
	trail.spread = 15.0
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 30.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 1.5
	trail.scale_amount_max = 2.5
	trail.color = Color(1.0, 0.85, 0.2, 0.6)
	add_child(trail)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.9, 0.3))
