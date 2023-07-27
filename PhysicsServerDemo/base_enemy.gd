extends Node2D
class_name BaseEnemy

# TODO: 联机模式下自动寻找最近的player

# 重要:
#	1. 把敌人初始朝向右侧
#	2. 别把scale搞成负数，我要用scale改敌人朝向

# 基础的近战敌人

@export var speed: int = 100
@export var hp: int = 100
@export var score: int = 10
@export var attack_speed: int = 1
@export var attack_damage: int = 10
@export var attack_range: int = 10

@export var spawn_interval: int = 100
@export var spwan_num: int = 1
@export var move_direct_interval: float = 0.5	# 低于0.0166的两倍（0.33）就没有意义，因为本来可以在physics_process中顺带检测的
@export var hurt_display_time: float = 0.2 # how much time to display hurt texture & material

@export var player_node_name: String = 'Player'
var player_node

@export var max_num: int = 500: 
	set(value):
		max_num = value
		warning_num = max_num * 0.8
var warning_num = max_num * 0.8

var spawn_timer = Timer.new()
var move_dir_detect_timer = Timer.new()

var running_base_transform: Transform2D
var running_texture: Texture2D
var running_material: ShaderMaterial
var running_collision_shape_base_transform: Transform2D

var idle_base_transform: Transform2D
var idle_texture: Texture2D
var idle_material: ShaderMaterial

var hurt_base_transform: Transform2D
var hurt_texture: Texture2D
var hurt_material: ShaderMaterial

var collision_mask = 0
var collision_layer = 0

var collision_shape2d

class Enemy:
	var position
	var speed
	var canvas_item_rid
	var dir
	var transform
	var collision_shape_transform
	var body_rid
	var flash_start_at = null
	var is_facing_right = true # 必须初始化建模为朝向右侧， godot算法会把transform2d.get_scale().x 永远返回正数，别用scale.x判断朝向！

var enemies: Array[Enemy] = []
var cur_enemy_num = 0

func _search_node_by_name(root, name):
	var children = root.get_children()
	for child in children:
		if child.name == name:
			return child
		var res = _search_node_by_name(child, name)
		if res:
			return res
	return null

func _init_variables():
	player_node = _search_node_by_name(get_tree().get_root(), player_node_name)
	collision_shape2d = get_node('Area2D').get_node('CollisionShape2D')
	
	running_texture = get_node('Area2D').get_node('Run').texture
	running_material = get_node('Area2D').get_node('Run').material
	running_base_transform = get_node('Area2D').get_node('Run').global_transform
	# running_collision_shape_base_transform = collision_shape2d.global_transform
	
	
	idle_texture = get_node('Area2D').get_node('Idle').texture
	idle_material = get_node('Area2D').get_node('Idle').material
	
	hurt_texture = get_node('Area2D').get_node('Hurt').texture
	hurt_material = get_node('Area2D').get_node('Hurt').material
	
	spawn_timer.set_wait_time(spawn_interval)
	spawn_timer.set_one_shot(false)
	spawn_timer.autostart = true
	spawn_timer.connect("timeout", _on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

	move_dir_detect_timer.set_wait_time(move_direct_interval)
	move_dir_detect_timer.set_one_shot(false)
	move_dir_detect_timer.connect("timeout", _detect_move_dir)
	add_child(move_dir_detect_timer)
	move_dir_detect_timer.start()
	
	collision_mask = get_node('Area2D').get_collision_mask()
	collision_layer = get_node('Area2D').get_collision_layer()
	print('mask: ', collision_mask, 'layer: ', collision_layer)
	
	

func _init_enemies_as_different_shape_in_an_area(enemy_shape_rid):
	pass

func _init_enemies_as_different_bodies(enemy_shape_rid):
	for _i in max_num:
		var enemy = enemies[_i]
		enemy.body_rid = PhysicsServer2D.body_create()
		PhysicsServer2D.body_set_space(enemy.body_rid, get_world_2d().get_space())
		PhysicsServer2D.body_add_shape(enemy.body_rid, enemy_shape_rid)
		
		# pool 中的怪物不检测，设为0
		PhysicsServer2D.body_set_collision_mask(enemy.body_rid, 0) # **因为不设置的话默认为1， 为0表示不处理，相当于null
		PhysicsServer2D.body_set_collision_layer(enemy.body_rid, 0) # 设置layer，可以不用，因为默认为1
		


func _physics_server_activate_enemy_as_different_body():
	pass

func _init_enemies_as_different_areas(enemy_shape_rid):
	pass

func _physics_server_set_new_transform(enemy, facing_right, new_position):
	# character不需要考虑rotation，只有左右
	var scale = running_collision_shape_base_transform.get_scale()
	var new_transform
	
	if facing_right:
		new_transform = Transform2D(
			running_collision_shape_base_transform.get_rotation(),
			scale,
			running_collision_shape_base_transform.get_skew(),
			new_position
		)
	else:
		scale.x *= -1
		new_transform = Transform2D(
			running_collision_shape_base_transform.get_rotation(),
			scale,
			running_collision_shape_base_transform.get_skew(),
			new_position
		)
	enemy.collision_shape_transform = new_transform
	PhysicsServer2D.body_set_state(enemy.body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, new_transform)

func _render_server_set_new_transform(enemy, facing_right, new_position):
	# character不需要考虑rotation，只有左右
	var scale = running_base_transform.get_scale()
	var new_transform
	
	if facing_right:
		new_transform = Transform2D(
			running_base_transform.get_rotation(),
			scale,
			running_base_transform.get_skew(),
			new_position
		)
	else:
		scale.x *= -1
		new_transform = Transform2D(
			running_base_transform.get_rotation(),
			scale,
			running_base_transform.get_skew(),
			new_position
		)
	enemy.transform = new_transform
	RenderingServer.canvas_item_set_transform(enemy.canvas_item_rid, new_transform)

func _ready():
	_init_variables()
	
	var parent_canvas_item = get_tree().current_scene
	
	var shape2d = collision_shape2d.shape
	var shape2d_rid
	# if is circle
	if shape2d is CircleShape2D:
		shape2d_rid = PhysicsServer2D.circle_shape_create()
		PhysicsServer2D.shape_set_data(shape2d_rid, shape2d.radius)
		print('Circle shape, radius: ', shape2d.radius)
	elif shape2d is RectangleShape2D:
		shape2d_rid = PhysicsServer2D.rectangle_shape_create()
		PhysicsServer2D.shape_set_data(shape2d_rid, shape2d.size)
		print(shape2d)
	else:
		assert(false, 'error: do not use capsule shape!!')

	for _i in max_num:
		var ci_rid = RenderingServer.canvas_item_create()
		var enemy = Enemy.new()
		enemy.canvas_item_rid = ci_rid
		enemy.speed = speed
		enemies.push_back(enemy)
		
		RenderingServer.canvas_item_set_parent(ci_rid, parent_canvas_item.get_canvas_item())
		RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(-running_texture.get_size() / 2, running_texture.get_size()), running_texture.get_rid())
		RenderingServer.canvas_item_set_material(ci_rid, running_material)
		
		RenderingServer.canvas_item_set_visible(ci_rid, false)
		
		enemy.body_rid = PhysicsServer2D.body_create()
		PhysicsServer2D.body_set_space(enemy.body_rid, get_world_2d().get_space())
		PhysicsServer2D.body_add_shape(enemy.body_rid, shape2d_rid)
		
		# pool 中的怪物不检测，设为0
		PhysicsServer2D.body_set_collision_mask(enemy.body_rid, 0) # **因为不设置的话默认为1， 为0表示不处理，相当于null
		PhysicsServer2D.body_set_collision_layer(enemy.body_rid, 0) # 设置layer，可以不用，因为默认为1
		
	# _init_enemies_as_different_bodies(shape2d_rid)
		
	get_node("Area2D").hide()
	var s : Area2D;
	get_node("Area2D").monitorable = false
	get_node("Area2D").monitoring = false
	
	_on_spawn_timer_timeout()
	
func get_camera_rect() -> Rect2:
	
	return Rect2()
	
func _on_spawn_timer_timeout():
	get_camera_rect()
	var spawn_positions = []
	for _i in spwan_num:
		# pick in viewport
		var viewport = get_viewport()
		var size = viewport.get_size()
		var x = randi() % size.x
		var y = randi() % size.y
		var pos = Vector2(x, y)
		spawn_positions.push_back(pos)
	spawn(spawn_positions)
	
func spawn(spawn_positions):
	for position in spawn_positions:
		if cur_enemy_num >= max_num:
			return
		var enemy = enemies[cur_enemy_num]
		enemy.position = position
		enemy.speed = speed
		enemy.flash_start_at = null
		
		# 检测player在左侧还是右侧
		var player_pos = player_node.global_position
		var dir = (player_pos - position).normalized()
		enemy.dir = dir
		# 如果在左侧
		if dir.x < 0:
			# var scale = running_base_transform.get_scale()
			# scale.x *= -1
			# enemy.is_facing_right = false
			# enemy.transform = Transform2D(
			# 	running_base_transform.get_rotation(),
			# 	scale,
			# 	running_base_transform.get_skew(),
			# 	position
			# )
			# RenderingServer.canvas_item_set_transform(enemy.canvas_item_rid, enemy.transform)
			
			_render_server_set_new_transform(enemy, false, position)

			# var collision_shape_scale = running_collision_shape_base_transform.get_scale()
			# collision_shape_scale.x *= -1
			# enemy.collision_shape_transform = Transform2D(
			# 	running_collision_shape_base_transform.get_rotation(),
			# 	collision_shape_scale,
			# 	running_collision_shape_base_transform.get_skew(),
			# 	position
			# )
			# PhysicsServer2D.body_set_state(enemy.body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, enemy.collision_shape_transform)
			_physics_server_set_new_transform(enemy, false, position)
		else:
			# enemy.transform = Transform2D(
			# 	running_base_transform.get_rotation(),
			# 	running_base_transform.get_scale(),
			# 	running_base_transform.get_skew(),
			# 	position
			# )
			# RenderingServer.canvas_item_set_transform(enemy.canvas_item_rid, enemy.transform)
			
			_render_server_set_new_transform(enemy, true, position)

			# enemy.collision_shape_transform = Transform2D(
			# 	running_collision_shape_base_transform.get_rotation(),
			# 	running_collision_shape_base_transform.get_scale(),
			# 	running_collision_shape_base_transform.get_skew(),
			# 	position
			# )
			# PhysicsServer2D.body_set_state(enemy.body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, enemy.collision_shape_transform)
			_physics_server_set_new_transform(enemy, true, position)
		RenderingServer.canvas_item_set_visible(enemy.canvas_item_rid, true)
		PhysicsServer2D.body_set_collision_mask(enemy.body_rid, collision_mask)
		PhysicsServer2D.body_set_collision_layer(enemy.body_rid, collision_layer)
		cur_enemy_num += 1
		
func _detect_move_dir():
	for _i in cur_enemy_num:
		var enemy = enemies[_i]
		var player_pos = player_node.global_position
		var dir = (player_pos - enemy.position).normalized()
		enemy.dir = dir
		# 如果在左侧
		if dir.x < 0 and _is_enemy_facing_right(enemy):	 # **错误！ builtin坑爹的scale算法，如果scale.x是负数，会把scale.x和scale.y同时乘以-1再旋转180度，所以每次get_scale().x都是正数，**不要用Transform2D.get_scale().x判断朝向！自己记录！
			
			# var scale = enemy.transform.get_scale()
			# scale.x *= -1
			# enemy.is_facing_right = false
			# enemy.transform = Transform2D(
			# 	enemy.transform.get_rotation(),
			# 	scale,
			# 	enemy.transform.get_skew(),
			# 	enemy.position
			# )
			# RenderingServer.canvas_item_set_transform(enemy.canvas_item_rid, enemy.transform)

			# var collision_shape_scale = enemy.collision_shape_transform.get_scale()
			# collision_shape_scale.x *= -1
			# enemy.collision_shape_transform = Transform2D(
			# 	enemy.collision_shape_transform.get_rotation(),
			# 	collision_shape_scale,
			# 	enemy.collision_shape_transform.get_skew(),
			# 	enemy.position
			# )
			# PhysicsServer2D.body_set_state(enemy.body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, enemy.collision_shape_transform)
			_physics_server_set_new_transform(enemy, false, enemy.position)
			_render_server_set_new_transform(enemy, false, enemy.position)

		elif dir.x > 0 and not _is_enemy_facing_right(enemy):
			# var scale = enemy.transform.get_scale()
			# scale.x *= -1
			# enemy.transform = Transform2D(
			# 	enemy.transform.get_rotation(),
			# 	scale,
			# 	enemy.transform.get_skew(),
			# 	enemy.position
			# )
			# RenderingServer.canvas_item_set_transform(enemy.body_rid, enemy.transform)


			# var collision_shape_scale = enemy.collision_shape_transform.get_scale()
			# collision_shape_scale.x *= -1
			# enemy.collision_shape_transform = Transform2D(
			# 	enemy.collision_shape_transform.get_rotation(),
			# 	collision_shape_scale,
			# 	enemy.collision_shape_transform.get_skew(),
			# 	enemy.position
			# )
			# PhysicsServer2D.body_set_state(enemy.body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, enemy.collision_shape_transform)
			_physics_server_set_new_transform(enemy, true, enemy.position)
			_render_server_set_new_transform(enemy, true, enemy.position)

func _is_enemy_facing_right(enemy):
	#	TODO: 用rotation可以检测么，那么只比较一个float更快
	
	# godot will multiply scale.x and scale.y by -1 and rotate 180 degree if scale.x is negative
	#	so can't not directly use scale.x to judge facing direction
	
	# case1:  (1, 1) 
	#	flip1: -> (-1, 1) -> (1, -1), 
	#	flip2: -> (-1, -1) -> (1, 1)
	# case2: (-1, 1)
	#	flip1: -> (1, 1) -> (-1, -1)
	#	flip2: -> (1, -1) -> (-1, 1)
	# case3: (1, -1)
	#	flip1: -> (-1, -1) -> (1, 1)
	#	flip2: -> (-1, 1) -> (1, -1)
	# case4: (-1, -1)
	#	flip1: -> (1, -1) -> (-1, 1)
	#	flip2: -> (1, 1) -> (-1, -1)

	# in any case, flipping 2 times will make scal(x, y) the same as origin
	#	thus if cur_scale == origin_scale, then it's facing right(the init facing must be right)
	var cur_scale = enemy.transform.get_scale()
	var base_scale = running_base_transform.get_scale()
	return cur_scale == base_scale


func _physics_process(delta):
	# move enemies
	for _i in cur_enemy_num:
		var enemy = enemies[_i]
		enemy.transform.origin += enemy.dir * enemy.speed * get_physics_process_delta_time()
		enemy.position = enemy.transform.origin
		enemy.collision_shape_transform.origin += enemy.dir * enemy.speed * get_physics_process_delta_time()
		# 坑点： 必须每帧调用body_set_state，不然就不会检测
		PhysicsServer2D.body_set_state(enemy.body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, enemy.collision_shape_transform)
		RenderingServer.canvas_item_set_transform(enemy.canvas_item_rid, enemy.transform)	

# func _flash(enemy: Enemy, cur_time: float):
# 	enemy.flash_start_at = cur_time
# 	RenderingServer.canvas_item_set_material(enemy.canvas_item_rid, goblin_material)

# func _cancel_flash(enemy: Enemy):
# 	enemy.flash_start_at = null
# 	RenderingServer.canvas_item_set_material(enemy.canvas_item_rid, goblin_material)
	
# func _ready():
# 	_ready_for_using_shader()

# func _physics_process(delta):
# 	for enemy in enemies:
# 		var random_move = Vector2(randf_range(-10, 10), randf_range(-10, 10))
# 		# 动态set texture会严重影响performance，只用transform移动可以支撑15000，加上设置texture只能支撑1500, 差了10倍
# 		# RenderingServer.canvas_item_add_texture_rect(enemy.canvas_item_rid, Rect2(goblin_texture.get_size() / 2, goblin_texture.get_size()), goblin_texture.get_rid())
# 		RenderingServer.canvas_item_set_transform(enemy.canvas_item_rid, Transform2D().rotated(deg_to_rad(45)).translated(random_move * delta * 100).translated(enemy.position))
		
