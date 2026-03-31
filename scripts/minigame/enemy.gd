class_name MinigameEnemy
extends Area2D

signal reached_station(damage: int)
signal died()
signal split_requested(pos: Vector2, split_type: String, count: int)

var hp: int = 1
var speed: float = 150.0
var damage_to_station: int = 1
var enemy_radius: float = 20.0
var color: Color = Color(0.6, 0.6, 0.5)
var split_on_death: bool = false
var split_type: String = ""
var split_count: int = 0
var _target: Vector2
var _flash_timer: float = 0.0

func setup(type_data: Dictionary, spawn_pos: Vector2, target: Vector2) -> void:
	position = spawn_pos
	_target = target
	hp = int(type_data.get("hp", 1))
	speed = randf_range(float(type_data.get("speed_min", 100)), float(type_data.get("speed_max", 200)))
	damage_to_station = int(type_data.get("damage_to_station", 1))
	enemy_radius = float(type_data.get("radius", 20))
	var c: Array = type_data.get("color", [0.6, 0.6, 0.5])
	color = Color(c[0], c[1], c[2])
	split_on_death = bool(type_data.get("split_on_death", false))
	split_type = str(type_data.get("split_type", ""))
	split_count = int(type_data.get("split_count", 0))

	var shape := CircleShape2D.new()
	shape.radius = enemy_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	collision_layer = 2
	collision_mask = 0

func _process(delta: float) -> void:
	var dir := (_target - position).normalized()
	position += dir * speed * delta

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			modulate = Color.WHITE

	if position.distance_to(_target) < 60.0:
		reached_station.emit(damage_to_station)
		queue_free()

func take_damage(amount: int) -> void:
	hp -= amount
	_flash_timer = 0.1
	modulate = Color(3.0, 3.0, 3.0)
	if hp <= 0:
		AudioManager.play_sfx("enemy_die")
		if split_on_death and split_count > 0:
			split_requested.emit(position, split_type, split_count)
		died.emit()
		queue_free()
	else:
		AudioManager.play_sfx("enemy_hit")

func _draw() -> void:
	draw_circle(Vector2.ZERO, enemy_radius, color)
	if hp > 1:
		draw_circle(Vector2.ZERO, enemy_radius * 0.6, color.darkened(0.3))
	draw_arc(Vector2.ZERO, enemy_radius, 0, TAU, 24, color.lightened(0.2), 2.0)
