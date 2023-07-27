extends Node2D

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

@export_group('Test Setting')
@export var stop_move = false

var spawn_timer = Timer.new()
var move_dir_detect_timer = Timer.new()

class MyTransform2D:
	var rotation
	var scale
	var skew
	var origin
	
	func _init(transform: Transform2D):
		rotation = transform.get_rotation()
		scale = transform.get_scale()
		skew = transform.get_skew()
		origin = transform.get_origin()
		

var running_base_transform: MyTransform2D
var running_texture: Texture2D
var running_material: ShaderMaterial
var running_collision_shape_base_transform: MyTransform2D

var idle_base_transform: MyTransform2D
var idle_texture: Texture2D
var idle_material: ShaderMaterial

var hurt_base_transform: MyTransform2D
var hurt_texture: Texture2D
var hurt_material: ShaderMaterial

var collision_mask = 0
var collision_layer = 0

var canvas_parent_rid

var space_rid
var running_collision_shape_rid


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
	canvas_parent_rid = get_tree().current_scene.get_canvas_item()

	var shape2d  = get_node('Area2D').get_node('RunShape').shape
	running_collision_shape_rid
	# if is circle
	if shape2d is CircleShape2D:
		running_collision_shape_rid = PhysicsServer2D.circle_shape_create()
		PhysicsServer2D.shape_set_data(running_collision_shape_rid, shape2d.radius)
		print('Circle shape, radius: ', shape2d.radius)
	elif shape2d is RectangleShape2D:
		running_collision_shape_rid = PhysicsServer2D.rectangle_shape_create()
		PhysicsServer2D.shape_set_data(running_collision_shape_rid, shape2d.size)
		print(shape2d)
	else:
		assert(false, 'error: do not use capsule shape!!')

	running_texture = get_node('Area2D').get_node('Run').texture
	running_material = get_node('Area2D').get_node('Run').material
	print('init: ')
	running_base_transform = MyTransform2D.new(get_node('Area2D').get_node('Run').global_transform)
	
	running_collision_shape_base_transform = MyTransform2D.new(get_node('Area2D').get_node('RunShape').global_transform)
	
	
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

	space_rid = get_world_2d().get_space()

func _init_enemies_as_different_bodies(enemy_shape_rid):
	for _i in max_num:
		var enemy = enemies[_i]
		enemy.body_rid = PhysicsServer2D.body_create()
		PhysicsServer2D.body_set_space(enemy.body_rid, get_world_2d().get_space())
		PhysicsServer2D.body_add_shape(enemy.body_rid, enemy_shape_rid)
		
		# pool 中的怪物不检测，设为0
		PhysicsServer2D.body_set_collision_mask(enemy.body_rid, 0) # **因为不设置的话默认为1， 为0表示不处理，相当于null
		PhysicsServer2D.body_set_collision_layer(enemy.body_rid, 0) # 设置layer，可以不用，因为默认为1

func _flip_h_transform(transform):
	var scale = transform.get_scale()
	scale.x *= -1
	return Transform2D(
		transform.get_rotation(),
		scale,
		transform.get_skew(),
		transform.get_origin()
	)

func move_enemy_to_new_position(enemy, new_enemy_position):
	enemy.position = new_enemy_position
	# change facing to the player
	var cur_player_global_position = player_node.global_position
	enemy.dir = (cur_player_global_position - new_enemy_position).normalized()
	enemy.is_facing_right = enemy.dir.x > 0
	# update transform with new scale for flipping and new position on servers
	_render_server_set_new_transform(enemy, new_enemy_position)
	_physics_server_set_new_transform(enemy, new_enemy_position)

func _physics_server_set_new_transform(enemy, new_position):
	# 用于改变 朝向 和 位置
	# character不需要考虑rotation，只有左右
	var scale = running_collision_shape_base_transform.scale
	if not enemy.is_facing_right:
		scale.x *= -1
	var new_transform = Transform2D(running_collision_shape_base_transform.rotation, scale, running_collision_shape_base_transform.skew, new_position)
	enemy.collision_shape_transform = new_transform
	PhysicsServer2D.body_set_state(enemy.body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, new_transform)

func _render_server_set_new_transform(enemy, new_position):
	var scale = running_base_transform.scale
	if not enemy.is_facing_right:
		scale.x *= -1
	var new_transform = Transform2D(running_base_transform.rotation, scale, running_base_transform.skew, new_position)
	enemy.transform = new_transform
	RenderingServer.canvas_item_set_transform(enemy.canvas_item_rid, new_transform)
	

func _ready():
	_init_variables()

	for _i in max_num:
		var ci_rid = RenderingServer.canvas_item_create()
		var enemy = Enemy.new()
		enemy.canvas_item_rid = ci_rid
		enemy.speed = speed
		enemies.push_back(enemy)
		
		RenderingServer.canvas_item_set_parent(ci_rid, canvas_parent_rid)
		RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(-running_texture.get_size() / 2, running_texture.get_size()), running_texture.get_rid())
		RenderingServer.canvas_item_set_material(ci_rid, running_material)
		RenderingServer.canvas_item_set_visible(ci_rid, false)
		
		enemy.body_rid = PhysicsServer2D.body_create()
		PhysicsServer2D.body_set_space(enemy.body_rid, space_rid)
		PhysicsServer2D.body_add_shape(enemy.body_rid, running_collision_shape_rid)
		# pool 中的怪物不检测，设为0
		PhysicsServer2D.body_set_collision_mask(enemy.body_rid, 0) # **因为不设置的话默认为1， 为0表示不处理，相当于null
		PhysicsServer2D.body_set_collision_layer(enemy.body_rid, 0) # 设置layer，可以不用，因为默认为1
		
	# _init_enemies_as_different_bodies(running_collision_shape_rid)
		
	get_node("Area2D").hide()
	var s : Area2D;
	get_node("Area2D").monitorable = false
	get_node("Area2D").monitoring = false
	
	_on_spawn_timer_timeout()
	
	
func _on_spawn_timer_timeout():
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
	for spawn_position in spawn_positions:
		if cur_enemy_num >= max_num:
			return
		var enemy = enemies[cur_enemy_num]
		enemy.speed = speed
		enemy.flash_start_at = null
		
		move_enemy_to_new_position(enemy, spawn_position)
		
		RenderingServer.canvas_item_set_visible(enemy.canvas_item_rid, true)
		PhysicsServer2D.body_set_collision_mask(enemy.body_rid, collision_mask)
		PhysicsServer2D.body_set_collision_layer(enemy.body_rid, collision_layer)
		cur_enemy_num += 1
		
func _detect_move_dir():
	# update enemies move direction to the player, and flip if need
	var cur_player_global_position = player_node.global_position
	for _i in cur_enemy_num:
		var enemy = enemies[_i]
		enemy.dir = (cur_player_global_position - enemy.position).normalized()
		var should_face_right = enemy.dir.x > 0
		if should_face_right != enemy.is_facing_right:
			enemy.is_facing_right = should_face_right
			_render_server_set_new_transform(enemy, enemy.position)
			_physics_server_set_new_transform(enemy, enemy.position)
		move_enemy_to_new_position(enemy, enemy.position)


func _is_enemy_facing_right(enemy):
	var cur_scale = enemy.transform.get_scale()
	var base_scale = running_base_transform.scale
	return cur_scale == base_scale


func _physics_process(delta):
	for _i in cur_enemy_num:
		var enemy = enemies[_i]
		enemy.transform.origin += enemy.dir * enemy.speed * get_physics_process_delta_time()
		enemy.position = enemy.transform.origin
		enemy.collision_shape_transform.origin += enemy.dir * enemy.speed * get_physics_process_delta_time()
		RenderingServer.canvas_item_set_transform(enemy.canvas_item_rid, enemy.transform)
		PhysicsServer2D.body_set_state(enemy.body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, enemy.collision_shape_transform)
