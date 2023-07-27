extends Node2D

@export var hit_flash_time = 0.1

const ENEMY_COUNT = 5000

var goblin_shader
var goblin_animation

var goblin_texture: Texture2D
var goblin_material: ShaderMaterial

var s:Sprite2D;

var cur_time = 0

var enemies: Array[Enemy] = []

class Enemy:
	static var running_texture
	static var running_material
	
	static var idle_texture
	static var idle_material
	
	static var hurt_texture
	static var hurt_material
	
	var position
	var velocity
	var rid
	
	var flash_start_at = null

func _ready_for_using_shader():
	
	goblin_shader = get_node("Goblin")
	goblin_shader.queue_free()

	var sprite2d = goblin_shader.get_node('Area2D').get_node('Run')
	goblin_texture = sprite2d.texture
	goblin_material = sprite2d.material
	
	for _i in ENEMY_COUNT:
		var ci_rid = RenderingServer.canvas_item_create()
		var enemy = Enemy.new()
		enemy.rid = ci_rid
		enemy.position = Vector2(randf_range(0, get_viewport().get_size().x), randf_range(0, get_viewport().get_size().y))
		enemy.velocity = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		enemies.push_back(enemy)
		# Make this node the parent.
		RenderingServer.canvas_item_set_parent(ci_rid, get_canvas_item())
		# Draw a texture on it.
		# Remember, keep this reference.
		# Add it, centered.
		RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(goblin_texture.get_size() / 2, goblin_texture.get_size()), goblin_texture.get_rid())
		RenderingServer.canvas_item_set_material(ci_rid, goblin_material)
		# RenderingServer.canvas_item_set_material(ci_rid, goblin_material.duplicate()) !!不要dup，会卡爆
		# Add the item, rotated 45 degrees and translated.
		var xform = Transform2D().rotated(deg_to_rad(45)).translated(Vector2(20, 30))
		xform.origin = enemy.position
		RenderingServer.canvas_item_set_transform(ci_rid, xform)

func _flash(enemy: Enemy, cur_time: float):
	enemy.flash_start_at = cur_time
	RenderingServer.canvas_item_set_material(enemy.rid, goblin_material)

func _cancel_flash(enemy: Enemy):
	enemy.flash_start_at = null
	RenderingServer.canvas_item_set_material(enemy.rid, goblin_material)
	
func _ready():
	_ready_for_using_shader()

func _physics_process(delta):
	for enemy in enemies:
		var random_move = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		# 动态set texture会严重影响performance，只用transform移动可以支撑15000，加上设置texture只能支撑1500, 差了10倍
		# RenderingServer.canvas_item_add_texture_rect(enemy.rid, Rect2(goblin_texture.get_size() / 2, goblin_texture.get_size()), goblin_texture.get_rid())
		RenderingServer.canvas_item_set_transform(enemy.rid, Transform2D().rotated(deg_to_rad(45)).translated(random_move * delta * 100).translated(enemy.position))
		

