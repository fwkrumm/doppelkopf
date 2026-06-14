extends Control
class_name DebugOverlay

@export var max_lines: int = 8
var lines: Array = []

var log = null

func _ready():
	visible = true
	# Defer node initialization to ensure child nodes are present after instantiation
	call_deferred("_init_nodes")

func _init_nodes() -> void:
	# Try direct lookup first
	log = get_node_or_null("Panel/Log")
	if not log:
		# fallback: find first TextEdit descendant
		log = _find_textedit(self)
	if not log:
		push_error("DebugOverlay: Log node not found")
		for c in get_children():
			print("DebugOverlay child:", c.name, "type:", c.get_class())
	else:
		log.text = ""
		log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Allow mouse events to pass through the overlay so UI remains clickable
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel = get_node_or_null("Panel")
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _find_textedit(node: Node) -> Node:
	for child in node.get_children():
		if child is TextEdit:
			return child
		var found = _find_textedit(child)
		if found:
			return found
	return null

func add_message(msg: String) -> void:
	lines.append(str(msg))
	if lines.size() > max_lines:
		lines.remove_at(0)
	var out = "\n".join(lines)
	if log:
		log.text = out
	else:
		print("DebugOverlay (no Log): ", out)
