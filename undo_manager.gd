extends Node2D

class_name UndoManager

@export var max_undo_stack_size = 200;

class Operation:
	func undo():
		pass;

class Transaction:
	var operations: Array[Operation] = [];
	
	func add_operation(op: Operation):
		operations.push_back(op);
		
	func undo():
		var rev = operations.duplicate();
		rev.reverse();
		
		for op: Operation in rev:
			op.undo();

var transactions: Array[Transaction] = []
		
var transaction: UndoManager.Transaction;
	
func start_transaction():
	transaction = UndoManager.Transaction.new();
	
func end_transaction():
	transactions.push_back(transaction);
	if transactions.size() > max_undo_stack_size:
		transactions.pop_front();
	transaction = null;
	
func clear_transaction():
	transaction = null;
	
func add_operation(op: Operation):
	transaction.add_operation(op);

func undo():
	if transactions.size() > 0:
		var trans: Transaction = transactions.pop_back();
		trans.undo();

func _ready() -> void:
	pass;

func _process(_delta: float) -> void:
	pass
