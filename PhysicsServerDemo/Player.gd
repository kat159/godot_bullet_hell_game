extends CharacterBody2D


const SPEED = 200.0
const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _physics_process(delta):
	# point the character in the direction of the mouse
	var mouse_pos = get_global_mouse_position()
	var direction = mouse_pos - get_global_position()
	direction = direction.normalized()
	look_at(mouse_pos)

	# move the character
	if Input.is_action_pressed("right"):
		velocity.x = SPEED
	elif Input.is_action_pressed("left"):
		velocity.x = -SPEED
	elif Input.is_action_pressed("up"):
		velocity.y = -SPEED
	elif Input.is_action_pressed("down"):
		velocity.y = SPEED
	else:
		velocity = Vector2.ZERO
	# normalize the velocity vector and multiply it by the speed
	velocity = velocity.normalized() * SPEED
	move_and_slide()


func _on_area_2d_area_entered(area: Area2D):
	print("area entered: ", area.name)


func _on_area_2d_area_exited(area):
	print("area exited: ", area.name)


func _on_area_2d_area_shape_entered(area_rid, area, area_shape_index, local_shape_index):
	print("area shape entered: --------------")
	print("area_rid: ", area_rid)
	print("area: ", area)
	print("area_shape_index: ", area_shape_index)
	print("local_shape_index: ", local_shape_index)


func _on_area_2d_area_shape_exited(area_rid, area, area_shape_index, local_shape_index):
	print("area shape exited: --------------")
	print("area_rid: ", area_rid)
	print("area: ", area)
	print("area_shape_index: ", area_shape_index)
	print("local_shape_index: ", local_shape_index)


func _on_area_2d_body_entered(body):
	print("body entered: ", body.name)


func _on_area_2d_body_exited(body):
	print("body exited: ", body.name)


func _on_area_2d_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	print("<<<<<<进去了: --------------")
	print("body_rid: ", body_rid)
	print("body: ", body)
	print("body_shape_index: ", body_shape_index)
	print("local_shape_index: ", local_shape_index)


func _on_area_2d_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	print(">>>>>>>离开: --------------")
	print("body_rid: ", body_rid)
	print("body: ", body)
	print("body_shape_index: ", body_shape_index)
	print("local_shape_index: ", local_shape_index)
