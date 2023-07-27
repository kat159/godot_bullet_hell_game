extends Node2D
# This demo is an example of controling a high number of 2D objects with logic
# and collision without using nodes in the scene. This technique is a lot more
# efficient than using instancing and nodes, but requires more programming and
# is less visual. Bullets are managed together in the `bullets.gd` script.

const image = preload("res://face_sad.png")

var shape
var pushable

class Pushable:
	var position = Vector2()
	var speed = 1.0
	# The body is stored as a RID, which is an "opaque" way to access resources.
	# With large amounts of objects (thousands or more), it can be significantly
	# faster to use RIDs compared to a high-level approach.
	var body = RID()


func _ready():
	shape = PhysicsServer2D.circle_shape_create()
	# Set the collision shape's radius for each bullet in pixels.
	PhysicsServer2D.shape_set_data(shape, 20)

	
	var pushable = Pushable.new()
	pushable.body = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_space(pushable.body, get_world_2d().get_space())
	PhysicsServer2D.body_add_shape(pushable.body, shape)
	# Don't make bullets check collision with other bullets to improve performance.
	PhysicsServer2D.body_set_collision_mask(pushable.body, 1) # **因为不设置的话默认为1， 为0表示不处理，相当于null
	PhysicsServer2D.body_set_collision_layer(pushable.body, 2) # 设置layer，可以不用，因为默认为1
	
	# make bullet push player when collide
	PhysicsServer2D.body_set_mode(pushable.body, PhysicsServer2D.BODY_MODE_KINEMATIC)
	PhysicsServer2D.body_set_constant_force(pushable.body, Vector2(100, 0))

	# Place bullets randomly on the viewport and move bullets outside the
	# play area so that they fade in nicely.
	pushable.position = Vector2(
		randf_range(0, get_viewport_rect().size.x),
		randf_range(0, get_viewport_rect().size.y)
	)
	var transform2d = Transform2D()
	transform2d.origin = pushable.position
	PhysicsServer2D.body_set_state(pushable.body, PhysicsServer2D.BODY_STATE_TRANSFORM, transform2d)
	
	self.pushable = pushable

func _process(_delta):
	# Order the CanvasItem to update every frame.
	queue_redraw()
	var info = PhysicsServer2D.get_process_info(1)


# Instead of drawing each bullet individually in a script attached to each bullet,
# we are drawing *all* the bullets at once here.
func _draw():
	if pushable.position:
		var offset = -image.get_size() * 0.5
		draw_texture(image, pushable.position + offset)


