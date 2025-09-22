extends Area2D

enum Direction { 
	UP = TileSet.CELL_NEIGHBOR_TOP_SIDE, 
	DOWN = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, 
	LEFT = TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	RIGHT = TileSet.CELL_NEIGHBOR_RIGHT_SIDE, 
	NONE = -1,
};

enum Axis {
	UD, LR
}

const DIR_AXIS: Dictionary[Direction, Axis] = {
	Direction.UP: Axis.UD,
	Direction.DOWN: Axis.UD,
	Direction.LEFT: Axis.LR,
	Direction.RIGHT: Axis.LR,
}

const DIRECTIONS: Array[Direction] = [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT];

const DIR_OFFSET: Dictionary = {
	Direction.UP: Vector2i(0,-1),
	Direction.DOWN: Vector2i(0,1),
	Direction.LEFT: Vector2i(-1,0),
	Direction.RIGHT: Vector2i(1,0),
}

const DIR_OPPOSITE: Dictionary = {
	Direction.UP: Direction.DOWN,
	Direction.DOWN: Direction.UP,
	Direction.LEFT: Direction.RIGHT,
	Direction.RIGHT: Direction.LEFT,
}

const CROSS_OFF = Vector2i(3,3);
const CROSS_LR_ON = Vector2i(4,3);
const CROSS_UD_ON = Vector2i(5,3);
const CROSS_ON = Vector2i(6,3);

class Wire:
	var tile_map: TileMapLayer;
	var tile_data: TileData;
	var tile_pos: Vector2i;
	var tile_source: int;
	var tile_atlas: Vector2i;

	func _init(map, pos):
		tile_map = map;
		tile_pos = pos;
		tile_data = tile_map.get_cell_tile_data(tile_pos);
		tile_source = tile_map.get_cell_source_id(tile_pos);
		tile_atlas = tile_map.get_cell_atlas_coords(tile_pos);
		
	func get_pos() -> Vector2i:
		return tile_pos;
		
	func get_atlas() -> Vector2i:
		return tile_atlas;
		
	func is_cross() -> bool:
		return tile_atlas == CROSS_OFF \
			|| tile_atlas == CROSS_LR_ON \
			|| tile_atlas == CROSS_UD_ON \
			|| tile_atlas == CROSS_ON;
			
	func to_cross(axis: Axis) -> CrossWire:
		return CrossWire.new(tile_map, tile_pos, axis);
		
	func is_self_powered() -> bool:
		return tile_data.get_custom_data("self_powered");
		
	func is_powered_state() -> bool:
		return tile_data.get_custom_data("powered");
		
	func is_powered(dir: Direction) -> bool:
		return tile_data.get_terrain_peering_bit(dir as TileSet.CellNeighbor) == 2;

	func is_conductive(dir: Direction) -> bool:
		return tile_data.get_terrain_peering_bit(dir as TileSet.CellNeighbor) != -1;
		
	func set_powered() -> void:
		if not self.is_powered_state():
			tile_map.put_cell(tile_pos, tile_source, tile_data.get_custom_data("counterpart"));
		
	func set_unpowered() -> void:
		if self.is_powered_state():
			tile_map.put_cell(tile_pos, tile_source, tile_data.get_custom_data("counterpart"));
		
	static var wires_map: TileMapLayer
	static var floor_wires_map: TileMapLayer
	static var gates_map: TileMapLayer
	
	static func set_maps(wires, floors, gates):
		wires_map = wires;
		floor_wires_map = floors;
		gates_map = gates;
		
	static func get_wire(pos: Vector2i, dir: Direction) -> Wire:
		var wire: Wire
		if wires_map.get_cell_tile_data(pos) != null:
			wire = Wire.new(wires_map, pos);
		elif floor_wires_map.get_cell_tile_data(pos) != null:
			wire = Wire.new(floor_wires_map, pos);
		
		if wire != null && wire.is_cross():
			return wire.to_cross(DIR_AXIS.get(dir));
		return wire;
		
	static func get_gate(pos: Vector2i) -> Gate:
		if gates_map.get_cell_source_id(pos) == Gate.BALLAST_SOURCE:
			return Gate.new(gates_map, pos);
		
		return null;
			
class CrossWire extends Wire:
	var axis: Axis;	
	
	func _init(map, pos, a):
		super(map, pos);
		axis = a;
		
	func is_conductive(dir: Direction) -> bool:
		if axis == Axis.UD and (dir == Direction.LEFT or dir == Direction.RIGHT):
			return false;
		if axis == Axis.LR and (dir == Direction.UP or dir == Direction.DOWN):
			return false;
		
		return tile_data.get_terrain_peering_bit(dir as TileSet.CellNeighbor) != -1;
		
	func set_powered() -> void:
		if axis == Axis.UD:
			if tile_atlas == CROSS_OFF:
				tile_map.put_cell(tile_pos, tile_source, CROSS_UD_ON);
			if tile_atlas == CROSS_LR_ON:
				tile_map.put_cell(tile_pos, tile_source, CROSS_ON);
		if axis == Axis.LR:
			if tile_atlas == CROSS_OFF:
				tile_map.put_cell(tile_pos, tile_source, CROSS_LR_ON);
			if tile_atlas == CROSS_UD_ON:
				tile_map.put_cell(tile_pos, tile_source, CROSS_ON);
		
	func set_unpowered() -> void:
		if axis == Axis.UD:
			if tile_atlas == CROSS_UD_ON:
				tile_map.put_cell(tile_pos, tile_source, CROSS_OFF);
			if tile_atlas == CROSS_ON:
				tile_map.put_cell(tile_pos, tile_source, CROSS_LR_ON);
		if axis == Axis.LR:
			if tile_atlas == CROSS_LR_ON:
				tile_map.put_cell(tile_pos, tile_source, CROSS_OFF);
			if tile_atlas == CROSS_ON:
				tile_map.put_cell(tile_pos, tile_source, CROSS_UD_ON);
	
class Gate extends Wire:
	static var BALLAST_SOURCE: int = 6;
	static var GATE_SOURCE: int = 4;
	
	var gates: Array[Vector2i] = []
	var dir: Direction
	
	func _init(map, pos):
		super(map, pos);
		
		for d: Direction in DIRECTIONS:
			if Wire.gates_map.get_cell_source_id(pos + DIR_OFFSET.get(d)) == GATE_SOURCE:
				dir = d;
		
		var gate_pos = pos + DIR_OFFSET.get(dir);
		while Wire.gates_map.get_cell_source_id(gate_pos) == GATE_SOURCE:
			gates.push_back(gate_pos);
			gate_pos += DIR_OFFSET.get(dir);
	
	func is_conductive(_dir: Direction) -> bool:
		return false;
		
	func set_powered() -> void:
		if not is_powered_state():
			tile_map.put_cell(tile_pos, tile_source, tile_data.get_custom_data("counterpart"));
			
			for gate_pos: Vector2i in gates:
				var data: TileData = tile_map.get_cell_tile_data(gate_pos);
				if not data.get_custom_data("powered"):
					tile_map.put_cell(gate_pos, GATE_SOURCE, data.get_custom_data("counterpart"));
					var wire = Wire.get_wire(gate_pos, dir);
					if wire != null:
						WireNetwork.new(wire).calculate();
		
	func set_unpowered() -> void:
		if is_powered_state():
			tile_map.put_cell(tile_pos, tile_source, tile_data.get_custom_data("counterpart"));
			
			for gate_pos: Vector2i in gates:
				var data: TileData = tile_map.get_cell_tile_data(gate_pos);
				if data.get_custom_data("powered"):
					tile_map.put_cell(gate_pos, GATE_SOURCE, data.get_custom_data("counterpart"));
					var wire = Wire.get_wire(gate_pos, dir);
					if wire != null:
						WireNetwork.new(wire).calculate();
	

class WireNetwork:
	var initial_wire: Wire
	var rigid: RigidBox

	func _init(wire: Wire) -> void:
		initial_wire = wire;
		
	func calculate_rigid(rigid: RigidBox):
		self.rigid = rigid;
		self.calculate();
		self.rigid = null;
		
	func calculate() -> void:
		var loops = false;
		var wires: Array[Wire] = [];
		var queue: Array[Wire] = [initial_wire];
		var dir_queue: Array[Direction] = [Direction.NONE];
		var visited: Dictionary[Vector2i, bool] = {}
		var powered: bool = false;
		var any_powered: bool = false;
		
		while queue.size() > 0:
			var wire: Wire = queue.pop_front();
			var last_dir: Direction = dir_queue.pop_front();
			
			if rigid != null && not rigid.visited.get(wire.get_pos()):
				continue;
				
			if wire.tile_map == Wire.floor_wires_map && Box.get_box(wire.get_pos()) != null:
				continue;
			
			visited.set(wire.get_pos(), true);
			wires.push_back(wire);
			
			var gate = Wire.get_gate(wire.get_pos());
			if gate != null:
				wires.push_back(gate);
				
			for dir in DIRECTIONS:
				if not wire.is_conductive(dir):
					continue;
				
				if wire.is_self_powered():
					loops = true;
					
				if wire.is_powered_state(): # not already powered
					any_powered = true;
					
				if dir == last_dir: 
					continue;
					
				var target_pos = wire.get_pos() + DIR_OFFSET.get(dir);
				var target_wire = Wire.get_wire(target_pos, dir);
				
				if Wire.gates_map.get_cell_source_id(target_pos) == Gate.GATE_SOURCE:
					var data: TileData = Wire.gates_map.get_cell_tile_data(target_pos);
					if not data.get_custom_data("powered") && data.get_terrain_peering_bit(DIR_OPPOSITE.get(dir)) != -1:
						continue;
				
				if target_wire != null and target_wire.is_conductive(DIR_OPPOSITE.get(dir)):
					if target_wire.is_cross():
						target_wire = target_wire.to_cross(DIR_AXIS.get(dir));
						queue.push_back(target_wire);
						dir_queue.push_back(DIR_OPPOSITE.get(dir));
					elif visited.get(target_pos):
						loops = true;
					else:
						queue.push_back(target_wire);
						dir_queue.push_back(DIR_OPPOSITE.get(dir));
				
			
		if any_powered and loops:
			powered = true;
			
		for wire: Wire in wires:
			if powered:
				wire.set_powered();	
			else:
				wire.set_unpowered();

class Box:
	static var box_map: TileMapLayer;
	static var wire_map: TileMapLayer;
	static var floor_wire_map: TileMapLayer;
	static var wall_map: TileMapLayer;
	
	var tile_data: TileData;
	var tile_pos: Vector2i;
	var tile_atlas: Vector2i;
	var tile_source: int;
	var rigid: RigidBox;

	func _init(pos):
		tile_pos = pos;
		tile_data = box_map.get_cell_tile_data(tile_pos);
		tile_source = box_map.get_cell_source_id(tile_pos);
		tile_atlas = box_map.get_cell_atlas_coords(tile_pos);
		
	func get_pos() -> Vector2i:
		return tile_pos;
		
	func is_extended(dir: Direction) -> bool: 
		return tile_data.get_terrain_peering_bit(dir as TileSet.CellNeighbor) != -1;
		
		
	func move(dir: Direction):
		var pos = tile_pos + DIR_OFFSET.get(dir);
		box_map.put_cell(tile_pos);
		
		var tile_wire = Wire.new(wire_map, tile_pos);
		
		var wire = Wire.new(floor_wire_map, tile_pos);
		var to_wire = Wire.new(floor_wire_map, pos);
		
		if wire.tile_source != -1 && to_wire.tile_source != -1:
			if tile_wire.tile_source != -1 && tile_wire.is_conductive(dir) && tile_wire.is_conductive(DIR_OPPOSITE.get(dir)):
				if wire.is_powered_state() && not to_wire.is_powered_state():
					to_wire.set_powered();
					rigid.update_wires(pos, dir);
				elif not wire.is_powered_state() && to_wire.is_powered_state():
					wire.set_powered();
					rigid.update_wires(tile_pos, DIR_OPPOSITE.get(dir));
			else:
				if wire.is_cross():
					floor_wire_map.put_cell(pos, wire.tile_source, CROSS_OFF);
				elif wire.is_powered_state():
					wire.set_unpowered();
		
		if wire.tile_source != -1:
			if wire.is_cross():
				floor_wire_map.put_cell(tile_pos, wire.tile_source, CROSS_OFF);
			elif wire.is_powered_state():
				wire.set_unpowered();
		
		if tile_wire.tile_source != -1:
			if tile_wire.is_self_powered():
				if tile_wire.is_conductive(DIR_OPPOSITE.get(dir)) && wire.tile_source != -1:
					if wire.is_powered_state(): 
						tile_wire.set_powered();
					elif tile_wire.is_powered_state():
						wire.set_powered();
						rigid.update_wires(tile_pos, DIR_OPPOSITE.get(dir));
					
				if tile_wire.is_conductive(dir) && to_wire.tile_source != -1:
					if to_wire.is_powered_state(): 
						tile_wire.set_powered();
					elif tile_wire.is_powered_state():
						to_wire.set_powered();
						rigid.update_wires(pos, dir);
			
			wire_map.put_cell(pos, wire_map.get_cell_source_id(tile_pos), wire_map.get_cell_atlas_coords(tile_pos));
			wire_map.put_cell(tile_pos);
		
		box_map.put_cell(pos, tile_source, tile_atlas);
		tile_pos = pos;
		
	static func get_box(pos: Vector2i) -> Box:
		if box_map.get_cell_source_id(pos) != -1:
			return Box.new(pos);
		return null;
		
	static func set_maps(box: TileMapLayer, wire: TileMapLayer, floor_wire: TileMapLayer, walls: TileMapLayer):
		box_map = box;
		wire_map = wire;
		floor_wire_map = floor_wire;
		wall_map = walls;

class RigidBox:
	var visited: Dictionary[Vector2i, bool] = {}
	var boxes: Array[Box] = [];
	
	var min_x: int = 9223372036854775807;
	var min_y: int = 9223372036854775807;
	var max_x: int = -9223372036854775808;
	var max_y: int = -9223372036854775808;
	
	func _init() -> void:
		pass;
		
	func add_boxes(start_pos: Vector2i):
		if visited.get(start_pos):
			return;
		
		var queue: Array[Box] = [Box.get_box(start_pos)];
		var dir_queue: Array[Direction] = [Direction.NONE];
		
		while queue.size() > 0:
			var box: Box = queue.pop_front();
			box.rigid = self;
			var last_dir = dir_queue.pop_front();
			
			if visited.get(box.get_pos()):
				continue;
			
			boxes.push_back(box);
			var box_pos: Vector2i = box.get_pos();
			visited.set(box_pos, true);
			
			if box_pos.x < min_x:
				min_x = box_pos.x;
			if box_pos.x > max_x:
				max_x = box_pos.x;
			if box_pos.y < min_y:
				min_y = box_pos.y;
			if box_pos.y > max_y:
				max_y = box_pos.y;
			
			for dir in DIRECTIONS:
				if last_dir == dir:
					continue;
					
				if box.is_extended(dir):
					var target_pos = box.get_pos() + DIR_OFFSET.get(dir);
					var target_box = Box.get_box(target_pos);
					
					queue.push_back(target_box);
					dir_queue.push_back(DIR_OPPOSITE.get(dir));
	
	func update_wires(selected_pos: Vector2i, update_dir: Direction) -> void:
		var initial_wire = Wire.get_wire(selected_pos, update_dir);
		if initial_wire == null:
			return;

		var network = WireNetwork.new(initial_wire);
		network.calculate();

	func push_box(push_dir: Direction) -> bool:
		var can_push: bool = true;
		var offset = DIR_OFFSET.get(push_dir);
		
		var loops = 1;
		while loops > 0:
			loops -= 1;
			
			for box: Box in boxes:
				var pos = box.get_pos() + offset;
				if visited.get(pos):
					continue;
				if Box.get_box(pos) != null:
					self.add_boxes(pos);
					loops += 1;
					break;
				var target_wall = Box.wall_map.get_cell_source_id(pos);
				if target_wall != -1:
					can_push = false;
					break;
				
		if can_push:
			var sorted_boxes = boxes.duplicate();
			if push_dir == Direction.LEFT || push_dir == Direction.RIGHT:
				sorted_boxes.sort_custom(func (a, b): return a.get_pos().x < b.get_pos().x);
			else:
				sorted_boxes.sort_custom(func (a, b): return a.get_pos().y < b.get_pos().y);
				
			if push_dir == Direction.RIGHT || push_dir == Direction.DOWN:
				sorted_boxes.reverse();
				
			var new_visited: Dictionary[Vector2i, bool] = {};
			var to_update: Array[Vector2i] = [];
			
			for box: Box in sorted_boxes:
				to_update.append(box.get_pos());
				box.move(push_dir);
				new_visited.set(box.get_pos(), true);
				to_update.append(box.get_pos());
			
			visited = new_visited;
			
			for box: Box in sorted_boxes:
				var wire = Wire.get_wire(box.get_pos(), push_dir);
				if wire != null:
					WireNetwork.new(wire).calculate_rigid(self);
					break;
			
			for pos: Vector2i in to_update:
				for dir in DIRECTIONS:
					self.update_wires(pos + DIR_OFFSET.get(dir), dir);
			
		return can_push;
		

func _ready() -> void:
	Wire.set_maps($Wires, $FloorWires, $Gates);
	Box.set_maps($Box, $Wires, $FloorWires, $Walls);
	
	$Camera2D.limit_left = $BottomBound.position.x;
	$Camera2D.limit_bottom = $BottomBound.position.y;
	$Camera2D.limit_top = $TopBound.position.y;
	$Camera2D.limit_right = $TopBound.position.x;
	
	DirAccess.open("user://").make_dir("saves");
	var dir_saves: DirAccess = DirAccess.open(saves_dir)
	var save_files: PackedStringArray = dir_saves.get_files();
	if save_files.size() > 0:
		var save_path: String = save_files.get(save_files.size() - 1);
		save_n = save_files.size();
		load_save(saves_dir + save_path);

func push_box(direction: Direction) -> bool:
	# todo:
	# - flashing
	#  - only really have to do the more visual ones 
	#  - gotta rework power transfer on push in general
	
	if rigid == null:
		return false;
		
	return rigid.push_box(direction);

var panning: bool = false;
var pan_pos: Vector2

var rigid: RigidBox

var saves_dir = "user://saves/"
var save_n = 0;

func save():
	var save_path = saves_dir + "save_" + str(save_n) + ".dat";
	var file = FileAccess.open(save_path, FileAccess.WRITE);
	
	var floor_layer: PackedByteArray = $FloorWires.tile_map_data;
	file.store_32(floor_layer.size());
	file.store_buffer(floor_layer);
	
	var box_layer: PackedByteArray = $Box.tile_map_data;
	file.store_32(box_layer.size());
	file.store_buffer(box_layer);
	
	var wire_layer: PackedByteArray = $Wires.tile_map_data;
	file.store_32(wire_layer.size());
	file.store_buffer(wire_layer);
	
	file.close();
	
	save_n += 1;
	
func load_save(save_path: String):
	var file = FileAccess.open(save_path, FileAccess.READ);
	
	var floor_layer: PackedByteArray = file.get_buffer(file.get_32())
	$FloorWires.tile_map_data = floor_layer;
	
	var box_layer: PackedByteArray = file.get_buffer(file.get_32());
	$Box.tile_map_data = box_layer;
	
	var wire_layer: PackedByteArray = file.get_buffer(file.get_32());
	$Wires.tile_map_data = wire_layer;
	
	file.close();

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("save"):
		save();
		return;
		
	if Input.is_action_just_pressed("undo"):
		$UndoManager.undo();
		return;
	
	if Input.is_action_just_pressed("pan"):
		panning = true;
		pan_pos = get_viewport().get_mouse_position();
	if Input.is_action_just_released("pan"):
		panning = false;
		
	if panning:
		var mouse_pos = get_viewport().get_mouse_position();
		var diff = pan_pos - mouse_pos;
		pan_pos = mouse_pos;
		
		$Camera2D.move_local_x(diff.x);
		$Camera2D.move_local_y(diff.y);
		return;
	
	if Input.is_action_pressed("select"):
		var clicked_pos = $Box.local_to_map($Box.get_local_mouse_position());
		if $Box.get_cell_source_id(clicked_pos) != -1:
			rigid = RigidBox.new();
			rigid.add_boxes(clicked_pos);
			
			$Selector.select_2(clicked_pos, Vector2i(rigid.min_x, rigid.min_y), Vector2i(rigid.max_x, rigid.max_y));
			$Selector.show();
		else:
			rigid = null;
			$Selector.hide();
			
		return;
	
	if !$Selector.visible:
		return;
		
	var dir = Direction.NONE
	
	if Input.is_action_just_pressed("move_right"):
		dir = Direction.RIGHT;
	if Input.is_action_just_pressed("move_left"):
		dir = Direction.LEFT;
	if Input.is_action_just_pressed("move_down"):
		dir = Direction.DOWN;
	if Input.is_action_just_pressed("move_up"):
		dir = Direction.UP;
		
	if dir == Direction.NONE:
		return;
	else:
		var new_pos = $Selector.get_pos();
		$UndoManager.start_transaction();
		if push_box(dir):
			new_pos += DIR_OFFSET.get(dir);
			$UndoManager.end_transaction();
		else:
			$UndoManager.clear_transaction();
			# make fail to push sound
		rigid = RigidBox.new();
		rigid.add_boxes(new_pos);
		$Selector.select(new_pos);
