class_name MinigameShockwave
extends Node2D

var damage: int = 3
var arc_angle: float = PI / 2.0
var direction_angle: float = 0.0
var radius_start: float = 80.0
var radius_end: float = 400.0
var duration: float = 0.3
var _elapsed: float = 0.0
var _hit_enemies: Array = []
var _enemies_ref: Node2D

func setup(data: Dictionary, swipe_angle: float, enemies: Node2D) -> void:
	damage = int(data.get("damage", 3))
	arc_angle = deg_to_rad(float(data.get("arc_degrees", 90)))
	radius_start = float(data.get("radius_start", 80))
	radius_end = float(data.get("radius_end", 400))
	duration = float(data.get("duration", 0.3))
	direction_angle = swipe_angle
	_enemies_ref = enemies

func _process(delta: float) -> void:
	_elapsed += delta
	_check_hits()
	queue_redraw()
	if _elapsed >= duration:
		queue_free()

func _check_hits() -> void:
	var current_radius := lerpf(radius_start, radius_end, _elapsed / duration)
	for enemy in _enemies_ref.get_children():
		if enemy in _hit_enemies:
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist := to_enemy.length()
		if dist > current_radius:
			continue
		var angle_to := to_enemy.angle()
		var angle_diff := wrapf(angle_to - direction_angle, -PI, PI)
		if absf(angle_diff) <= arc_angle / 2.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			_hit_enemies.append(enemy)

func _draw() -> void:
	var t := _elapsed / duration
	var current_radius := lerpf(radius_start, radius_end, t)
	var alpha := 1.0 - t
	var half_arc := arc_angle / 2.0
	var color := Color(0.3, 0.8, 1.0, alpha * 0.6)
	var points: PackedVector2Array = [Vector2.ZERO]
	var steps := 12
	for i in range(steps + 1):
		var a := direction_angle - half_arc + (arc_angle / steps) * i
		points.append(Vector2.from_angle(a) * current_radius)
	draw_colored_polygon(points, color)
