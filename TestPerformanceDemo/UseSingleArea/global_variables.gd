extends Node2D
class_name GlobalVariables


"""
	when a type of bullet or enemy removed from the game, corresponding index in shape_index_to_object will be set to null
	and the index will be added to available_start_indices_of_shape_index_to_object, so next time when a new bullet or enemy
	is created, it can use the index to replace the null value in shape_index_to_object

	example:
	shape_index_to_object:
		[0,    1,    2,    3,    4,    5,    6]
		[null, null, obj, obj, null, null, obj]

	available_start_indices_of_shape_index_to_object:
		[0, 4] or maybe [4, 0]
"""
var shape_index_to_object = []
var available_start_indices_of_shape_index_to_object = [] # when no available index, add a new one to the end of the list

var area_rid_to_object = {}
