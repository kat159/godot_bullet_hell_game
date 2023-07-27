extends Node2D

var n = 10000
var space_rid
var area_rid

func _area_enter_callback(a, b, c, d, e):
	print(2222222222)
	
func _ready():
	# var space_rid = PhysicsServer2D.space_create()
	space_rid = get_world_2d().get_space()
	area_rid = PhysicsServer2D.area_create()
	PhysicsServer2D.area_set_collision_layer(area_rid, 2)
	PhysicsServer2D.area_set_collision_mask(area_rid, 1)
	PhysicsServer2D.area_set_space(area_rid, space_rid)
	PhysicsServer2D.area_set_monitorable(area_rid, true) # 默认为false，改成true其他人也能检测
	PhysicsServer2D.area_set_area_monitor_callback(area_rid, _area_enter_callback)
	# PhysicsServer2D.area_set_monitor_callback(area_rid, _area_enter_callback)
	var shape_rid = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(shape_rid, 10)
	for _i in n:
		PhysicsServer2D.area_add_shape(area_rid, shape_rid, Transform2D(), false)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	for _i in n:
		PhysicsServer2D.area_set_shape_transform(area_rid, _i, Transform2D())
