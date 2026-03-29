class_name MinigameProjectile
extends Area2D

var speed: float = 600.0
var damage: int = 1
var direction: Vector2 = Vector2.ZERO
var _lifetime: float = 3.0

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

func _process(delta: float) -> void:
	position += direction * speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0 or position.x < -100 or position.x > 1200 or position.y < -100 or position.y > 2100:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.3))
