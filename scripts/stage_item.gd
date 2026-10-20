class_name StageItem
extends Area2D

var riding := false
var consumed := false
var velocity := Vector2.ZERO
var hover_height := 16.0

const GRAVITY := 1800.0


func _ready() -> void:
	add_to_group("items")
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	monitorable = false


func _physics_process(delta: float) -> void:
	if consumed or riding:
		return
	var hit := _ray()
	if hit.is_empty():
		velocity.y += GRAVITY * delta
		global_position += velocity * delta
		if global_position.y > 1300.0:
			queue_free()
		return
	velocity = Vector2.ZERO
	global_position.y = hit.position.y - hover_height


func fall() -> void:
	if consumed:
		return
	riding = false
	velocity = Vector2(randf_range(-40.0, 40.0), 40.0)


func attach_to(fragment: Node2D) -> void:
	var kept := global_position
	reparent(fragment)
	global_position = kept
	riding = true
	velocity = Vector2.ZERO


func _ray() -> Dictionary:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, hover_height + 22.0))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)
