class_name MinigameTurret
extends Node2D

var fire_interval: float = 1.5
var projectile_speed: float = 600.0
var projectile_damage: int = 1
var turret_range: float = 900.0
var _fire_timer: float = 0.0
var _enemies_ref: Node2D
var _projectiles_ref: Node2D
var _target_angle: float = 0.0

func setup(data: Dictionary, enemies: Node2D, projectiles: Node2D) -> void:
	fire_interval = float(data.get("fire_interval", 1.5))
	projectile_speed = float(data.get("projectile_speed", 600))
	projectile_damage = int(data.get("projectile_damage", 1))
	turret_range = float(data.get("range", 900))
	_enemies_ref = enemies
	_projectiles_ref = projectiles
	_fire_timer = randf_range(0.0, fire_interval)

func _process(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		var target := _find_nearest_enemy()
		if target:
			_fire_timer = fire_interval
			_target_angle = (target.global_position - global_position).angle()
			_fire_at(target)
			queue_redraw()

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := turret_range
	for enemy in _enemies_ref.get_children():
		var dist := global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _fire_at(target: Node2D) -> void:
	var proj := MinigameProjectile.new()
	proj.setup(global_position, target.global_position, projectile_speed, projectile_damage)
	_projectiles_ref.add_child(proj)
	AudioManager.play_sfx("turret_fire")

func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(0.3, 0.7, 0.9))
	var barrel_end := Vector2.from_angle(_target_angle) * 18.0
	draw_line(Vector2.ZERO, barrel_end, Color(0.5, 0.85, 1.0), 3.0)
