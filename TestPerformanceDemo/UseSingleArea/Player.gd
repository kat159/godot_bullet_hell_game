extends Node2D
# This demo is an example of controling a high number of 2D objects with logic
# and collision without using nodes in the scene. This technique is a lot more
# efficient than using instancing and nodes, but requires more programming and
# is less visual. Bullets are managed together in the `bullets.gd` script.

# The number of bullets currently touched by the player.
var touching = 0

@onready var sprite = $AnimatedSprite2D


func _ready():
	# The player follows the mouse cursor automatically, so there's no point
	# in displaying the mouse cursor.
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _input(event):
	# Getting the movement of the mouse so the sprite can follow its position.
	if event is InputEventMouseMotion:
		position = event.position - Vector2(0, 16)


func _on_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	# Player got touched by a bullet so sprite changes to sad face.
	# int('body shape entered: ', 'id: ', _body_id, 'body: ', _body, 'body_shape_index: ', _body_shape, 'local_shape_index: ', _local_shape)
	touching += 1
	if touching >= 1:
		sprite.frame = 1


func _on_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	touching -= 1
	# When non of the bullets are touching the player,
	# sprite changes to happy face.
	if touching == 0:
		sprite.frame = 0



func _on_area_shape_entered(area_rid, area, area_shape_index, local_shape_index):
	print('enter')
	touching += 1
	if touching >= 1:
		sprite.frame = 1
	# print('enter: ', 'area_rid: ', area_rid, 'area: ', area, 'area_shape_index: ', area_shape_index, 'local_shape_index: ', local_shape_index)


func _on_area_shape_exited(area_rid, area, area_shape_index, local_shape_index):
	print('exit')
	# print('exit: ', 'area_rid: ', area_rid, 'area: ', area, 'area_shape_index: ', area_shape_index, 'local_shape_index: ', local_shape_index)
	touching -= 1
	# When non of the bullets are touching the player,
	# sprite changes to happy face.
	if touching == 0:
		sprite.frame = 0
