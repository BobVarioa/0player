extends TileMapLayer

@export_custom(PROPERTY_HINT_NODE_TYPE, "UndoManager") var undo_manager: UndoManager

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

class TileOperation extends UndoManager.Operation:
	var map: TileMapLayer;
	var tile_pos: Vector2i;
	var old_source: int;
	var old_atlas: Vector2i;
	
	func _init(map, tile_pos, old_source, old_atlas):
		self.map = map; 
		self.tile_pos = tile_pos; 
		self.old_source = old_source; 
		self.old_atlas = old_atlas; 
		
	func undo():
		map.set_cell(tile_pos, old_source, old_atlas);
	
func put_cell(pos: Vector2i, source: int = -1, atlas: Vector2i = Vector2i(-1,-1), alternative_tile: int = 0):
	undo_manager.add_operation(TileOperation.new(self, pos, self.get_cell_source_id(pos), self.get_cell_atlas_coords(pos)))
	super.set_cell(pos, source, atlas, alternative_tile);
