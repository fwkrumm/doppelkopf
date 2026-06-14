extends Node3D
## A physical 3D playing card lying flat on the table.
## Face side faces +Y (up). Back side faces -Y (down).
## Emits clicked(card_node) when interactable and left-clicked.

signal clicked(card_node: Node3D)

## The card resource this visual represents.
var card = null
## Which player owns this card in the hand (-1 for trick/unowned).
var player_id: int = -1
## Whether the front face is visible (true = face-up, false = face-down).
var face_up: bool = false
## When true the Area3D responds to mouse input.
var interactive: bool = false

# Card dimensions (world units). Real card ratio ≈ 0.714 : 1.
const W: float = 0.63
const H: float = 1.0
const DEPTH: float = 0.010

const SUIT_SYM: Dictionary = {
	"CLUBS": "♣", "SPADES": "♠", "HEARTS": "♥", "DIAMONDS": "♦"
}
const RANK_NAME: Dictionary = {
	9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"
}
const SUIT_COLOR: Dictionary = {
	"HEARTS":   Color(0.85, 0.08, 0.08),
	"DIAMONDS": Color(0.82, 0.28, 0.0),
	"CLUBS":    Color(0.05, 0.10, 0.35),
	"SPADES":   Color(0.05, 0.05, 0.12),
}

var _face_mesh: MeshInstance3D = null
var _back_mesh: MeshInstance3D = null
var _label: Label3D = null
var _area: Area3D = null
var _face_mat: StandardMaterial3D = null

func _ready() -> void:
	_build()

func _build() -> void:
	# ── front face (white plane, faces +Y) ──────────────────────────────
	var front_plane := PlaneMesh.new()
	front_plane.size = Vector2(W, H)
	_face_mesh = MeshInstance3D.new()
	_face_mesh.mesh = front_plane
	_face_mat = StandardMaterial3D.new()
	_face_mat.albedo_color = Color.WHITE
	_face_mat.roughness = 0.3
	_face_mesh.material_override = _face_mat
	_face_mesh.position.y = DEPTH * 0.5 + 0.0003
	add_child(_face_mesh)

	# ── back face (blue plane, faces -Y via 180° X rotation) ────────────
	var back_plane := PlaneMesh.new()
	back_plane.size = Vector2(W, H)
	_back_mesh = MeshInstance3D.new()
	_back_mesh.mesh = back_plane
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.10, 0.18, 0.52)
	back_mat.roughness = 0.4
	_back_mesh.material_override = back_mat
	_back_mesh.rotation_degrees.x = 180.0
	_back_mesh.position.y = -(DEPTH * 0.5 + 0.0003)
	add_child(_back_mesh)

	# ── card edge (thin box for thickness) ──────────────────────────────
	var edge_box := BoxMesh.new()
	edge_box.size = Vector3(W, DEPTH, H)
	var edge_mesh := MeshInstance3D.new()
	edge_mesh.mesh = edge_box
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.94, 0.94, 0.92)
	edge_mesh.material_override = edge_mat
	add_child(edge_mesh)

	# ── rank + suit label (lies flat on front face) ──────────────────────
	_label = Label3D.new()
	_label.font_size = 72
	_label.pixel_size = 0.0035
	_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_label.rotation_degrees.x = -90.0
	_label.position = Vector3(0.0, DEPTH * 0.5 + 0.004, 0.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)

	# ── suit color strip along left edge ────────────────────────────────
	var strip_plane := PlaneMesh.new()
	strip_plane.size = Vector2(W * 0.12, H * 0.92)
	var strip_mesh := MeshInstance3D.new()
	strip_mesh.mesh = strip_plane
	var strip_mat := StandardMaterial3D.new()
	strip_mat.albedo_color = Color(0.9, 0.9, 0.9)
	strip_mesh.material_override = strip_mat
	strip_mesh.position = Vector3(-(W * 0.5 - W * 0.06), DEPTH * 0.5 + 0.001, 0.0)
	strip_mesh.name = "SuitStrip"
	add_child(strip_mesh)

	# ── collision area ───────────────────────────────────────────────────
	_area = Area3D.new()
	_area.input_ray_pickable = false  # off by default; enabled via set_interactive()
	var cshape := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(W + 0.04, DEPTH + 0.06, H + 0.04)
	cshape.shape = bshape
	_area.add_child(cshape)
	_area.input_event.connect(_on_area_input)
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)
	add_child(_area)

# ── public API ───────────────────────────────────────────────────────────────

## Assigns the card resource and sets initial face orientation.
func setup(card_res, face_up_flag: bool = false) -> void:
	card = card_res
	face_up = face_up_flag
	_refresh_visuals()

## Flips the card face-up without animation (instant reveal).
func reveal() -> void:
	face_up = true
	_refresh_visuals()

## Enables or disables click/hover input.
func set_interactive(enabled: bool) -> void:
	interactive = enabled
	_area.input_ray_pickable = enabled

## Animates the card flipping to face-up (180° Y rotation simulating a flip).
func animate_flip() -> void:
	face_up = true
	_refresh_visuals()
	# Start hidden, spring-scale in to simulate flip
	scale = Vector3(0.05, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)

## Slides this card to world_pos over duration seconds, optionally flipping.
func slide_to(world_pos: Vector3, duration: float, flip: bool = false) -> void:
	var tw := create_tween()
	# Rise slightly while moving for a natural arc
	var mid := (global_position + world_pos) * 0.5 + Vector3(0, 0.5, 0)
	# Simple linear slide (Godot doesn't have bezier tween built-in, so two steps)
	tw.tween_property(self, "global_position", mid, duration * 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "global_position", world_pos, duration * 0.55) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if flip:
		# Reveal mid-flight
		var flip_tw := create_tween()
		flip_tw.tween_interval(duration * 0.4)
		flip_tw.tween_callback(func():
			face_up = true
			_refresh_visuals()
			scale = Vector3(0.05, 1.0, 1.0)
			var s := create_tween()
			s.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.22) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)
		)

## Slides card off-screen toward world_pos then queues_free.
func slide_off(world_pos: Vector3, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "global_position", world_pos, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), duration) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

# ── private ──────────────────────────────────────────────────────────────────

func _refresh_visuals() -> void:
	if not card:
		_label.visible = false
		return
	if face_up:
		var sym: String = SUIT_SYM.get(card.suit, "?")
		var rk: String = RANK_NAME.get(card.rank, str(card.rank))
		_label.text = "%s  %s" % [rk, sym]
		var sc: Color = SUIT_COLOR.get(card.suit, Color.BLACK)
		_label.modulate = sc
		_label.visible = true
		_face_mat.albedo_color = Color.WHITE
		# Tint the suit strip
		var strip = get_node_or_null("SuitStrip")
		if strip:
			var sm: StandardMaterial3D = strip.material_override
			if sm:
				sm.albedo_color = sc.lerp(Color.WHITE, 0.55)
	else:
		_label.visible = false

func _on_area_input(_camera: Node, event: InputEvent, _pos: Vector3,
		_normal: Vector3, _shape_idx: int) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func _on_mouse_entered() -> void:
	if not interactive:
		return
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + 0.09, 0.10) \
		.set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	if not interactive:
		return
	var tw := create_tween()
	tw.tween_property(self, "position:y", 0.015, 0.12) \
		.set_ease(Tween.EASE_OUT)
