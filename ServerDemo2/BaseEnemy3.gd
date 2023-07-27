extends Node2D

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
	var physics_server_rid
	var flash_start_at = null
	var is_facing_right = true # 必须初始化建模为朝向右侧， godot算法会把transform2d.get_scale().x 永远返回正数，别用scale.x判断朝向！

const enemy_image = preload("res://bullet.png")

var enemies: Array[Enemy] = []
var shape

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
	
	
	collision_mask = get_node('Area2D').get_collision_mask()
	collision_layer = get_node('Area2D').get_collision_layer()
	print('mask: ', collision_mask, 'layer: ', collision_layer)

func _init_enemies_array():
	for _i in max_num:
		var enemy = Enemy.new()
		enemies.push_back(enemy)
		
func _init_enemies_as_different_bodies(enemy_shape_rid):
	for _i in max_num:
		var enemy = enemies[_i]
		enemy.speed = speed
		enemy.physics_server_rid = PhysicsServer2D.body_create()
		PhysicsServer2D.body_set_space(enemy.physics_server_rid, get_world_2d().get_space())
		PhysicsServer2D.body_add_shape(enemy.physics_server_rid, enemy_shape_rid)
		
		# pool 中的怪物不检测，设为0
		PhysicsServer2D.body_set_collision_mask(enemy.physics_server_rid, 0) # **因为不设置的话默认为1， 为0表示不处理，相当于null
		PhysicsServer2D.body_set_collision_layer(enemy.physics_server_rid, 0) # 设置layer，可以不用，因为默认为1
	
func spawn(spawn_positions):
	for position in spawn_positions:
		if cur_enemy_num >= max_num:
			return
		var enemy = enemies[cur_enemy_num]
		enemy.position = position
		
		var player_pos = player_node.global_position
		var dir = (player_pos - position).normalized()
		enemy.dir = dir
		
		var transform = Transform2D(
			running_collision_shape_base_transform.get_rotation(),
			running_collision_shape_base_transform.get_scale(),
			running_collision_shape_base_transform.get_skew(),
			position
		)
		PhysicsServer2D.body_set_state(enemy.physics_server_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, transform)
		PhysicsServer2D.body_set_collision_mask(enemy.physics_server_rid, collision_mask)
		PhysicsServer2D.body_set_collision_layer(enemy.physics_server_rid, collision_layer)
		cur_enemy_num += 1

func _ready():
	_init_variables()

	var shape2d = collision_shape2d.shape
	# if is circle
	if shape2d is CircleShape2D:
		shape = PhysicsServer2D.circle_shape_create()
		PhysicsServer2D.shape_set_data(shape, shape2d.radius)
	elif shape2d is RectangleShape2D:
		shape = PhysicsServer2D.rectangle_shape_create()
		PhysicsServer2D.shape_set_data(shape, shape2d.extents)
	else:
		assert(false, 'error: do not use capsule shape!!')

	# shape = PhysicsServer2D.circle_shape_create()
	# # Set the collision shape's radius for each enemy in pixels.
	# PhysicsServer2D.shape_set_data(shape, 8)
	
	_init_enemies_array()
	_init_enemies_as_different_bodies(shape2d)
	
	for _i in max_num:
		var rand_pos = Vector2(
			randf_range(0, get_viewport_rect().size.x) + get_viewport_rect().size.x,
			randf_range(0, get_viewport_rect().size.y)
		)
		spawn([rand_pos])

func _process(_delta):
	# Order the CanvasItem to update every frame.
	queue_redraw()


func _physics_process(delta):
	var transform2d = Transform2D()
	var offset = get_viewport_rect().size.x + 16
	for enemy in enemies:
		enemy.position.x -= enemy.speed * delta

		if enemy.position.x < -16:
			# Move the enemy back to the right when it left the screen.
			enemy.position.x = offset

		transform2d.origin = enemy.position
		PhysicsServer2D.body_set_state(enemy.physics_server_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, transform2d)


# Instead of drawing each enemy individually in a script attached to each enemy,
# we are drawing *all* the enemies at once here.
func _draw():
	var offset = -enemy_image.get_size() * 0.5
	for enemy in enemies:
		draw_texture(enemy_image, enemy.position + offset)


# Perform cleanup operations (required to exit without error messages in the console).
func _exit_tree():
	for enemy in enemies:
		PhysicsServer2D.free_rid(enemy.physics_server_rid)

	PhysicsServer2D.free_rid(shape)
	enemies.clear()
