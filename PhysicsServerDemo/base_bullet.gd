extends Node2D
# 重要： 1. 不要在最高节点改变参数，比如transform，会导致canvas通过global_position获得位置不对，
#		如果最高节点transform改变，这里不会处理获取相对transform，因为会导致额外计算
#		因为RenderingServer.canvas_item_set_transform(bullet.rid, transform)设置的是相对位置
#		而canvas_item只能设置为最高结点的child，不能设为root的，获取的global也是最高节点的
#		如果最高节点position变成(10, 10), canvas_item设置transform的position也变成(10,10)
#		那么相对position就变成了20,20了
#		2. 不要改变Sprite的Offset数据，这里也没有去处理，因为会导致额外计算！
#			如果需要flip，可以通过设置transform中的scale，设为负数就是flip
#			offset的所有param必须用默认的

		
@export var damage: float = 10
@export var hit_effect_duration: float = 0.5
@export var speed: float = 50
@export var time_to_live: float = 5
@export var turn_speed: float = 30
# 如果following_target定义在这里，那么可以是鼠标点哪里，所有的子弹都去实时更换目标，跟踪鼠标现在指向或改变的目标
#   如果是shoot(following_target), 存在子弹里，那么那个子弹类型属于射出去后只固定跟踪那个目标
var following_target # following bullet can only following a specific target, otherwise will affect performance a lot to keep finding nearest enemy

@export var max_bullet_amount: int = 5000:
	set(num):
		warning_bullet_num = max_bullet_amount * 0.8
var warning_bullet_num = max_bullet_amount * 0.8

@export var trigger_input: String = "left_mouse"
@export var shoot_speed: float = 1:	# shoot_speed bullets per second
	set(val):
		shoot_speed = val
		timer.wait_time = 1 / shoot_speed

var SHOTGUN_MODE_CLOSE = 0
var SHOTGUN_MODE_FAN_OUT_FIXED_RANGE = 1
var SHOTGUN_MODE_FAN_OUT_RANDOM_ANGLE = 2
@export_enum("Close", "Fan Out Fixed Range", "Fan Out Random Angle") var shotgun_mode: int
var bullets_num_per_shot
var deviation_degree_per_bullet
var deviation_random_range


@export var shotgun_bullets_num: int ; # how many bullets shot at the same time
@export var shotgun_deviation_per_bullet: float: # shotgun_mode = 1: fan out bullets from current direction, more bullets, more deviation from current direction
	set(val):
		# shotgun_deviation_per_bullet = deg_to_rad(val)	# **不要改输入，不然改完会改变editor的数据，下次启动又重复触发这个set
		shotgun_deviation_per_bullet = val
@export var shotgun_random_deviation_range: float: # shotgun_mode = 2: multi bullets shot from random deviation range based on current direction
	set(val):
		shotgun_random_deviation_range = val


@export var holding_hammer = false:
	set(value):
		holding_hammer = value
		notify_property_list_changed()
var hammer_type

func _get_property_list():
	# By default, `hammer_type` is not visible in the editor.
	var property_usage = PROPERTY_USAGE_NO_EDITOR

	if holding_hammer:
		property_usage = PROPERTY_USAGE_DEFAULT

	var properties = []
	properties.append({
		"name": "hammer_type",
		"type": TYPE_INT,
		"usage": property_usage, # See above assignment.
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Wooden,Iron,Golden,Enchanted"
	})

	return properties

var timer = Timer.new()


var flying_sprite2d: Sprite2D
var flying_texture: Texture2D
var flying_material
var flying_sprite2d_scale
# HitProperties:	# properties used when the bullet hits something, 定义在一起，可以增加cache命中率
#var damage

var hit_effect_texture
var hit_effect_material
#var hit_effect_duration
var hit_sound
var hit_sound_volume
var hit_sound_pitch

var collision_mask
var collision_layer


# FlyingProperties:	# properties used when the bullet is flying, normaly used in like _pyhsics_process
class Bullet:
	var rid
	var transform
	var direction
	var position
	# properties used for dealing the _process during flying
	var speed: float # speed可能用于子弹减速技能
	var time_to_live
	var following_target # following bullet can only following a specific target, otherwise will affect performance a lot to keep finding nearest enemy
	var turn_speed # speed和turn speed虽然是常量，每个子弹都一样，但是放在一起，可以增加cache命中率, 空间换时间


var bullets = []
var bullet_used = 0
# init to [0, 1, ..., max_bullet_amount - 1]
var RANDOM_INDICES = []
var cur_index_in_random_indices = 0
func _init_random_indices():
	for i in range(max_bullet_amount):
		RANDOM_INDICES.append(i)
	# shuffle the indices
	for i in range(max_bullet_amount):
		var random_index = randi() % max_bullet_amount
		var temp = RANDOM_INDICES[i]
		RANDOM_INDICES[i] = RANDOM_INDICES[random_index]
		RANDOM_INDICES[random_index] = temp

func _swap_bullet(index1, index2):
	var temp = bullets[index1]
	bullets[index1] = bullets[index2]
	bullets[index2] = temp

func _randomly_remove_bullets(number_to_remove):
	for i in range(number_to_remove):
		if bullet_used <= 0:
			break
		var random_index = RANDOM_INDICES[cur_index_in_random_indices]
		cur_index_in_random_indices = (cur_index_in_random_indices + 1) % max_bullet_amount
		if random_index >= bullet_used: # this cause the number of bullets removed might be smaller than number_to_remove
			continue
		var bullet = bullets[random_index]
		RenderingServer.canvas_item_set_visible(bullet.rid, false)
		bullet_used -= 1
		_swap_bullet(random_index, bullet_used)

func _ready():
	timer.connect('timeout', shoot)
	timer.wait_time = shoot_speed
	add_child(timer)	# 必须先add_child()，再start(), 不然没用
	
	_init_random_indices()

	flying_sprite2d = get_node("Area2D").get_node("Flying")
	var res = _get_sprite2d_base_transform(flying_sprite2d)
	var rotation_anchor_point = res['rotation_anchor_point']
	flying_sprite2d_scale = res['scale']
	
	flying_texture = flying_sprite2d.get_texture()
	flying_material = flying_sprite2d.get_material()

	var area2d = get_node("Area2D")
	
	collision_mask = area2d.collision_mask
	collision_layer = area2d.collision_layer
	
	# TODO: 可以设置parent
	var parent = get_tree().current_scene
		
	for _i in max_bullet_amount:
		var ci_rid = RenderingServer.canvas_item_create()
		var bullet = Bullet.new()
		bullet.speed = speed
		bullet.time_to_live = time_to_live
		bullet.turn_speed = turn_speed
		bullet.rid = ci_rid
		bullets.push_back(bullet)

		# config RenderingServer-------------------
		# RenderingServer.canvas_item_set_parent(ci_rid, get_canvas_item())	# 错误！这样的话如果bullet放到player里面，bullet就会跟着player移动， 要把parent设为最外层
		RenderingServer.canvas_item_set_parent(ci_rid, parent.get_canvas_item())
		# **坑爹教程， Rect2(position, size), 这里如果是16*16的texture，position就变成了8*8.也就是偏离了原点x=8，y=8，导致后面rotate出错
		# RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(flying_texture.get_size() / 2, flying_texture.get_size()), flying_texture.get_rid())
		# position设置成-flying_texture.get_size() / 2，就相当于centered，通过transform进行rotate就会以中心点旋转
		# RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(rotation_anchor_point, flying_texture.get_size()), flying_texture.get_rid())
		RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(-flying_texture.get_size() / 2, flying_texture.get_size()), flying_texture.get_rid())
		RenderingServer.canvas_item_set_material(ci_rid, flying_material)
		RenderingServer.canvas_item_set_visible(ci_rid, false)

		# config PhysicsServer-------------------
	
	get_node("Area2D").hide()
	get_node("Area2D").monitorable = false
	get_node("Area2D").monitoring = false
	# get_node("Area2D").queue_free() # 通过node直接拿实时位置，不free
	
func remove_bullet(bullet_rid):
	RenderingServer.canvas_item_set_visible(bullet_rid, false)
	bullet_used -= 1

func shoot_one_bullet(transform, direction):
	var bullet = bullets[bullet_used]
	bullet.transform = transform
	bullet.direction = direction
	bullet.position = transform.get_origin()
	bullet.time_to_live = time_to_live # 必须重新设置，不然升级子弹碰撞次数没法改变
	bullet.following_target = following_target # 必须重新设置，不然鼠标移动没法改变目标
	bullet.turn_speed = turn_speed	# 必须重新设置，不然升级bullet速度没法改变数据
	bullet.speed = speed
	RenderingServer.canvas_item_set_transform(bullet.rid, transform)
	RenderingServer.canvas_item_set_visible(bullet.rid, true)
	bullet_used += 1

func shoot():
	if bullet_used >= warning_bullet_num:
		_randomly_remove_bullets(max_bullet_amount / 10)
		return
	
	var transform = flying_sprite2d.global_transform
	var mouse_direction = (get_global_mouse_position() - transform.get_origin()).normalized()

	if shotgun_bullets_num <= 0:
		shoot_one_bullet(transform, mouse_direction)
	else:
		if shotgun_deviation_per_bullet > 0:
			var lower_angle = -shotgun_deviation_per_bullet * (shotgun_bullets_num - 1) / 2
			for i in range(shotgun_bullets_num):
				var deviation_angle = lower_angle + i * shotgun_deviation_per_bullet
				var bullet_direction = mouse_direction.rotated(deviation_angle)
				var new_transform = Transform2D(transform.get_rotation() + deviation_angle, flying_sprite2d_scale, transform.get_skew(), transform.get_origin())
				# print('new_transform: ', new_transform)
				# print('rotated: ', transform.rotated(deviation_angle)) # transform2d.rotated会以(0, 0)旋转origin点，所以不对， 自动通过ratotion+position设置transform
				shoot_one_bullet(new_transform, bullet_direction)
		elif shotgun_random_deviation_range > 0:
			for _i in shotgun_bullets_num:
				var deviation_angle = randf_range(-shotgun_random_deviation_range, shotgun_random_deviation_range)
				var bullet_direction = mouse_direction.rotated(deviation_angle)
				var new_transform = Transform2D(transform.get_rotation() + deviation_angle, flying_sprite2d_scale, transform.get_skew(), transform.get_origin())
				shoot_one_bullet(new_transform, bullet_direction)
		else:
			shoot_one_bullet(transform, mouse_direction)
			print('Warn: Shotgun Num > 0 but no angle has been set')

	
func _physics_process(delta):
	for i in bullet_used:
		var bullet = bullets[i]
		# change bullet position according to speed
		var transform = bullet.transform
		var speed = bullet.speed
		bullet.transform.origin = bullet.transform.origin + bullet.direction * speed * delta
		RenderingServer.canvas_item_set_transform(bullet.rid, bullet.transform)

func _process(delta):
	if Input.is_action_just_pressed(trigger_input):
		shoot()
		timer.start()
		
	elif Input.is_action_just_released(trigger_input):
		timer.stop()
		
func _get_sprite2d_base_transform(sprite2d: Sprite2D):
	# 思路：
	#	1.  Offset的Centered和Offset：
	# 			只会影响sprite2d的中心点（旋转的中心点和偏移量），
	# 			通过返回offset，在_ready中RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(offset, flying_texture.get_size()), flying_texture.get_rid())
	# 			注册canvas_item的offset来处理
	# 	2. Offset的flip_h和flip_v：
	# 			通过返回scale来处理, 在shoot()的时候，通过RenderingServer.canvas_item_set_transform(bullet.rid, transform)
	# 				tranform包含scale来处理
	# 	3. Node2D的Transform数据：
	# 		除了scale，其他的都直接用实时的global数据就行

	# Sprite2D的Offset params(属于sprite2d独有，*并且不会冒泡*，不会如果parent是sprite2d，不会受parent的Offset params影响
	var _offset = sprite2d.offset
	var centered = sprite2d.centered
	var flip_h = sprite2d.flip_h
	var flip_v = sprite2d.flip_v
	
	# Node2D的Transform数据
	var global_position = sprite2d.global_position
	var global_rotation = sprite2d.global_rotation
	var global_scale = sprite2d.global_scale
	var global_skew = sprite2d.global_skew
	
	# 1. 计算旋转中心点
	var rotation_anchor_point = Vector2(0, 0)
	if centered:	# 处理Offset.Centered逻辑
		rotation_anchor_point = -sprite2d.texture.get_size() / 2
		# multiply by abs(scale)
		rotation_anchor_point.x *= abs(global_scale.x)
		rotation_anchor_point.y *= abs(global_scale.y)
	# Offset.Offset也是影响旋转中心点
	rotation_anchor_point += _offset

	var base_position_offset = Vector2()
	# 2. convert flip_h, flip_v to scale
	if flip_h:
		global_scale.x *= -1
	if flip_v:
		global_scale.y *= -1
	
	var res = {
		'rotation_anchor_point': rotation_anchor_point,
		'scale': global_scale
	}
	return res
	
	
func _get_sprite2d_base_transform_with_converting_centered_rotation(sprite2d: Sprite2D):
	# 如果_ready的时候RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(-flying_texture.get_size() / 2 , flying_texture.get_size()), flying_texture.get_rid())
	# 	没有把Rect2的position设为中心点-flying_texture.get_size() / 2而是Vector2(0, 0), 
	#	通过RenderingServer.canvas_item_set_transform(bullet.rid, transform)设置旋转的时候
	#	就会以0,0旋转，这个方法可以通过offset position修正偏离的中心点距离
	# Sprite2D的Offset params(属于sprite2d独有，并且不会冒泡，不会如果parent是sprite2d，不会受parent的Offset params影响
	var _offset = sprite2d.offset
	var centered = sprite2d.centered
	var flip_h = sprite2d.flip_h
	var flip_v = sprite2d.flip_v
	
	# Node2D的Transform数据
	var global_position = sprite2d.global_position
	var global_rotation = sprite2d.global_rotation
	var global_scale = sprite2d.global_scale
	var global_skew = sprite2d.global_skew
	
	# convert centered to base_position_offset
	var base_position_offset = Vector2()
	if centered:
		base_position_offset = -sprite2d.texture.get_size() / 2
		# multiply by abs(scale)
		base_position_offset.x *= abs(global_scale.x)
		base_position_offset.y *= abs(global_scale.y)
		# consider change of rotation
		base_position_offset = base_position_offset.rotated(global_rotation)
	# convert offset to base_position_offset
	base_position_offset += _offset

	# convert flip_h, flip_v to scale
	if flip_h:
		global_scale.x *= -1
	if flip_v:
		global_scale.y *= -1
	
	# get final transform
	var transform = Transform2D(global_rotation, global_scale, global_skew, global_position + base_position_offset)
	return transform
