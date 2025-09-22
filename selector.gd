@tool
extends Node2D

var selected: bool = false;
var selector_pos: Vector2i;

@export var map: TileMapLayer;

@export var distance: int = 11;
@export var corner_scale: int = 40;

@export_tool_button("Update", "Callable") var update = update_corners;

func update_corners():
	self.get_node("TopLeft").set_scale(Vector2.ONE * 1.0 / corner_scale)
	self.get_node("TopRight").set_scale(Vector2.ONE * 1.0 / corner_scale)
	self.get_node("BottomLeft").set_scale(Vector2.ONE * 1.0 / corner_scale)
	self.get_node("BottomRight").set_scale(Vector2.ONE * 1.0 / corner_scale)
	
	self.get_node("TopLeft").set_position(Vector2(-distance, -distance));
	self.get_node("TopRight").set_position(Vector2(distance, -distance));
	self.get_node("BottomLeft").set_position(Vector2(-distance, distance));
	self.get_node("BottomRight").set_position(Vector2(distance, distance));

func select(pos: Vector2i):
	selector_pos = pos;
	var in_world_pos = map.map_to_local(pos);
	self.set_position(in_world_pos);

func select_2(pos: Vector2i, in_pos: Vector2i, out_pos: Vector2i):
	selector_pos = pos;
	var in_world_pos = map.map_to_local(pos);
	self.set_position(in_world_pos);
	
	var min_pos: Vector2 = map.map_to_local(in_pos) - in_world_pos;
	var max_pos: Vector2 = map.map_to_local(out_pos) - in_world_pos;
	
	$TopLeft.set_position(min_pos + Vector2(-distance, -distance));
	$TopRight.set_position(Vector2(max_pos.x, min_pos.y) + Vector2(distance, -distance));
	$BottomLeft.set_position(Vector2(min_pos.x, max_pos.y) + Vector2(-distance, distance));
	$BottomRight.set_position(max_pos + Vector2(distance, distance));

func get_pos():
	return selector_pos;
