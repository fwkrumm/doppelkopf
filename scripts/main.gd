extends Control
## Entry point. Builds the 3D world inside a SubViewport and wires up the
## game model. A CanvasLayer sits above the SubViewport for 2D UI elements.

const GameModel3D = preload("res://scripts/ui/game_3d.gd")

var _game_scene: Node = null   # game_3d instance (Node3D inside SubViewport)
var _canvas: CanvasLayer = null

func _ready() -> void:
	print("[Main] _ready")
	# Root Control fills the Window — anchor chain propagates every resize.
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	# ── SubViewportContainer fills the entire window ──────────────────────────────────
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(svc)

	# ── SubViewport owns the 3D world ─────────────────────────────────────
	var svp := SubViewport.new()
	svp.own_world_3d = true
	svp.handle_input_locally = true
	svp.transparent_bg = false
	# Required for Area3D.input_event / mouse_entered / mouse_exited to fire.
	svp.physics_object_picking = true
	# Smooth edges: 4× MSAA + FXAA post-process
	svp.msaa_3d = Viewport.MSAA_4X
	svp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	svc.add_child(svp)

	# ── Camera ────────────────────────────────────────────────────────────
	var cam := Camera3D.new()
	cam.fov = 52.0
	# look_at() requires being in the tree; use look_at_from_position() instead
	cam.look_at_from_position(Vector3(0.0, 6.0, 4.5), Vector3(0.0, 0.0, 0.3), Vector3.UP)
	svp.add_child(cam)

	# ── Lighting ──────────────────────────────────────────────────────────
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	svp.add_child(sun)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.55)
	env.ambient_light_energy = 0.9
	env_node.environment = env
	svp.add_child(env_node)

	# ── 3D game scene ─────────────────────────────────────────────────────
	_game_scene = GameModel3D.new()
	_game_scene.name = "GameScene3D"
	svp.add_child(_game_scene)
	_game_scene.build_world()

	# ── CanvasLayer for 2D UI overlay ────────────────────────────────────
	# IMPORTANT: must live INSIDE svp, not as a sibling of svc.
	# If it were in the main viewport, it would process all GUI mouse events
	# before SubViewportContainer._gui_input runs, killing both 3D picking
	# and button input. Inside svp, the SubViewport arbitrates 2D GUI and
	# 3D physics picking together within one input pass.
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	svp.add_child(_canvas)

	# Rules button in the overlay
	var rules_btn := Button.new()
	rules_btn.text = "Rules Config"
	rules_btn.position = Vector2(10, 10)
	rules_btn.pressed.connect(_on_rules_btn)
	_canvas.add_child(rules_btn)

	# ── Game model ────────────────────────────────────────────────────────
	var gm = preload("res://scripts/game_model.gd").new()
	gm.name = "GameModel"
	add_child(gm)

	# Wire 3D UI to the model (must happen before start_game)
	_game_scene.setup(gm, _canvas)
	gm.start_game()

	# Bring game window to front so editor doesn't intercept input
	get_window().title = "Doppelkopf"
	# Ensure no maximum window size is silently imposed.
	get_window().max_size = Vector2i(0, 0)
	get_window().grab_focus()

	print("[Main] ready complete")

func _on_rules_btn() -> void:
	print("[Main] RulesButton pressed")
	if has_node("RulesConfigInstance"):
		get_node("RulesConfigInstance").show()
		return
	var packed = load("res://scenes/rules_config.tscn")
	if not packed:
		push_error("[Main] failed to load rules_config.tscn")
		return
	var inst = packed.instantiate()
	inst.name = "RulesConfigInstance"
	add_child(inst)
