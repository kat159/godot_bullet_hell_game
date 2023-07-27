extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("right"):
		position.x += 10
	if Input.is_action_pressed("left"):
		position.x -= 10
	if Input.is_action_pressed("up"):
		position.y -= 10
	if Input.is_action_pressed("down"):
		position.y += 10


func _on_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	print("body shape entered: --------------")
	print("body_rid: ", body_rid)
	print("body: ", body)
	print("body_shape_index: ", body_shape_index)
	print("local_shape_index: ", local_shape_index)


func _on_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	print("body shape exited: --------------")
	print("body_rid: ", body_rid)
	print("body: ", body)
	print("body_shape_index: ", body_shape_index)
	print("local_shape_index: ", local_shape_index)
