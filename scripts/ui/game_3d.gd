extends Node3D
## 3D visual layer for the Doppelkopf game.
## Manages the 3D world (table, cards, camera) and a 2D CanvasLayer overlay
## (status labels, score display, buttons).
## Instantiate this node, add it to the SubViewport scene tree, then call setup().

const CardNode3D = preload("res://scripts/card_3d.gd")

# Shared lookup tables reused by multiple functions
const SUIT_SYM: Dictionary = {"CLUBS": "♣", "SPADES": "♠", "HEARTS": "♥", "DIAMONDS": "♦"}
const RANK_NAME: Dictionary = {9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"}
const SUIT_COL_2D: Dictionary = {
	"HEARTS":   Color(0.68, 0.12, 0.12),
	"DIAMONDS": Color(0.72, 0.26, 0.05),
	"CLUBS":    Color(0.08, 0.18, 0.42),
	"SPADES":   Color(0.10, 0.10, 0.22),
}

# ── layout constants ─────────────────────────────────────────────────────────

# Y height cards rest at (just above table surface)
const CARD_Y: float = 0.015
# Spacing between cards in the human hand
const HAND_SPACING: float = 0.72
# Human hand centre Z position (near camera / south)
const HAND_Z: float = 3.2
# Trick slot positions indexed by player_id
const TRICK_SLOTS: Array = [
	Vector3( 0.0,  CARD_Y,  1.15),   # P0 south
	Vector3(-1.15, CARD_Y,  0.0),    # P1 west  (clockwise: south → west → north → east)
	Vector3( 0.0,  CARD_Y, -1.15),   # P2 north
	Vector3( 1.15, CARD_Y,  0.0),    # P3 east
]
# Where collected tricks slide off to (one corner per player)
const COLLECT_POS: Array = [
	Vector3( 5.0, 0.0,  4.5),    # P0 south → SE corner
	Vector3(-5.0, 0.0,  4.5),    # P1 west  → SW corner
	Vector3(-5.0, 0.0, -4.5),    # P2 north → NW corner
	Vector3( 5.0, 0.0, -4.5),    # P3 east  → NE corner
]
# Bot identifier label positions (3D world, above table)
const BOT_LABEL_POS: Array = [
	Vector3.ZERO,               # unused (P0 is human)
	Vector3(-4.0, 0.5,  0.0),  # P1 west  (clockwise from south)
	Vector3( 0.0, 0.5, -3.8),  # P2 north
	Vector3( 4.0, 0.5,  0.0),  # P3 east
]
# Deck spawn position (cards dealt from here)
const DECK_POS: Vector3 = Vector3(3.8, 0.6, -2.8)

# ── state ────────────────────────────────────────────────────────────────────

var _gm: Node = null                   # GameModel reference
## card_3d nodes currently in the human's hand; index matches hand index
var _hand_cards: Array = []
## callable per hand card node so the hand-play handler can be cleanly disconnected
var _hand_callbacks: Dictionary = {}
## card_3d nodes currently in the trick area, keyed by player_id
var _trick_cards: Dictionary = {}
## trick cards cached for "Letzter Stich" overlay
var _last_trick_data: Array = []       # Array of {player_id, card, node}

# ── 2D overlay nodes (CanvasLayer added by main.gd) ──────────────────────────
var _canvas: CanvasLayer = null
var _status_lbl: Label = null
var _scores_lbl: Label = null
var _info_lbl: Label = null
var _stich_labels: Array = []
var _last_trick_btn: Button = null
var _last_trick_overlay: Control = null
var _last_trick_cards_row: HBoxContainer = null
var _last_trick_winner_lbl: Label = null

# ── entry point ──────────────────────────────────────────────────────────────

## Called by main.gd after this node is in the tree.
## canvas_layer must already be a child of the top-level scene so it renders
## above the SubViewport.
func setup(game_model: Node, canvas_layer: CanvasLayer) -> void:
	_gm = game_model
	_canvas = canvas_layer
	_build_2d_overlay()
	_gm.round_started.connect(_on_round_started)
	_gm.card_played.connect(_on_card_played)
	_gm.trick_completed.connect(_on_trick_completed)
	_gm.trick_pause_ended.connect(_on_trick_pause_ended)
	_gm.round_ended.connect(_on_round_ended)
	_gm.human_turn_started.connect(_on_human_turn)
	_gm.play_rejected.connect(_on_play_rejected)

# ── 3D world construction ─────────────────────────────────────────────────────

## Builds the table surface, ambient decor, and bot name labels.
## Called by main.gd before setup().
func build_world() -> void:
	_build_table()
	_build_bot_labels()

func _build_table() -> void:
	# Green felt table
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	var table := MeshInstance3D.new()
	table.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.36, 0.18)
	mat.roughness = 0.9
	table.material_override = mat
	table.name = "Table"
	add_child(table)

	# Slightly lighter centre oval to mark the playing area
	var oval := PlaneMesh.new()
	oval.size = Vector2(5.5, 5.5)
	var oval_mesh := MeshInstance3D.new()
	oval_mesh.mesh = oval
	var oval_mat := StandardMaterial3D.new()
	oval_mat.albedo_color = Color(0.16, 0.42, 0.21)
	oval_mat.roughness = 0.85
	oval_mesh.material_override = oval_mat
	oval_mesh.position.y = 0.001
	add_child(oval_mesh)

func _build_bot_labels() -> void:
	for i in range(1, 4):
		var lbl := Label3D.new()
		lbl.text = "Bot P%d" % i
		lbl.font_size = 38
		lbl.pixel_size = 0.005
		lbl.modulate = Color(1.0, 0.9, 0.7)
		lbl.position = BOT_LABEL_POS[i]
		add_child(lbl)

# ── 2D overlay ────────────────────────────────────────────────────────────────

func _build_2d_overlay() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# IGNORE: GUI traversal skips the container itself so sibling controls
	# (rules_btn) and the 3D SubViewport below can still receive clicks.
	# Children with MOUSE_FILTER_STOP (buttons) are checked independently.
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(vbox)

	_status_lbl = _make_lbl("Doppelkopf — starting…", 18, Color.WHITE)
	_status_lbl.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(_status_lbl)

	_scores_lbl = _make_lbl("", 15, Color(0.9, 0.9, 0.6))
	_scores_lbl.custom_minimum_size = Vector2(0, 22)
	vbox.add_child(_scores_lbl)

	vbox.add_child(HSeparator.new())

	# Stich count row + last-trick button on the same line
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)

	var stich_hbox := HBoxContainer.new()
	stich_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stich_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stich_hbox.add_theme_constant_override("separation", 6)
	row.add_child(stich_hbox)
	for i in range(4):
		var sl := _make_lbl("P%d: 0 ★" % i, 14, Color(0.8, 0.8, 0.8))
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stich_hbox.add_child(sl)
		_stich_labels.append(sl)

	_last_trick_btn = Button.new()
	_last_trick_btn.text = "Letzter Stich"
	_last_trick_btn.disabled = true
	_last_trick_btn.pressed.connect(_on_last_trick_btn)
	row.add_child(_last_trick_btn)

	# Transparent spacer — IGNORE so it doesn't swallow clicks meant for 3D cards
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	_info_lbl = _make_lbl("", 15, Color.WHITE)
	_info_lbl.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(_info_lbl)

	# Last-trick overlay (hidden by default, full-screen)
	_last_trick_overlay = _build_last_trick_overlay()
	_canvas.add_child(_last_trick_overlay)
	_last_trick_overlay.hide()

func _make_lbl(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	return l

func _build_last_trick_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 20
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 200)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Letzter Stich"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_last_trick_winner_lbl = Label.new()
	_last_trick_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_trick_winner_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	vb.add_child(_last_trick_winner_lbl)

	_last_trick_cards_row = HBoxContainer.new()
	_last_trick_cards_row.add_theme_constant_override("separation", 10)
	vb.add_child(_last_trick_cards_row)

	var close_btn := Button.new()
	close_btn.text = "Schließen"
	close_btn.pressed.connect(func(): overlay.hide())
	vb.add_child(close_btn)

	return overlay

# ── hand management ───────────────────────────────────────────────────────────

func _clear_hand() -> void:
	_hand_callbacks.clear()
	for c in _hand_cards:
		if is_instance_valid(c):
			c.queue_free()
	_hand_cards.clear()

func _build_hand_from_model(interactive: bool) -> void:
	_clear_hand()
	var human = _get_human()
	if not human:
		return
	var n: int = human.hand.size()
	if n == 0:
		return
	var total_width: float = (n - 1) * HAND_SPACING
	var start_x: float = -total_width * 0.5
	for i in range(n):
		var card_res = human.hand[i]
		var node: Node3D = CardNode3D.new()
		add_child(node)
		node.global_position = Vector3(start_x + i * HAND_SPACING, CARD_Y, HAND_Z)
		node.setup(card_res, true)
		node.set_interactive(interactive)
		var idx := i
		var hand_cb := func(cn): _on_hand_card_clicked(idx)
		node.clicked.connect(hand_cb)
		_hand_callbacks[node] = hand_cb
		_hand_cards.append(node)

func _get_human():
	if not _gm:
		return null
	for p in _gm.players:
		if not p.is_bot:
			return p
	return null

## Refreshes interactivity on all hand cards.
func _set_hand_interactive(enabled: bool) -> void:
	for i in range(_hand_cards.size()):
		if is_instance_valid(_hand_cards[i]):
			_hand_cards[i].set_interactive(enabled)

# ── deal animation ────────────────────────────────────────────────────────────

## Animate cards flying from the deck to each hand slot.
func _animate_deal() -> void:
	_build_hand_from_model(false)
	for i in range(_hand_cards.size()):
		var node: Node3D = _hand_cards[i]
		var dest: Vector3 = node.global_position
		node.global_position = DECK_POS
		node.scale = Vector3(0.6, 0.6, 0.6)
		var delay: float = i * 0.07
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(node, "global_position", dest, 0.28) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(node, "scale", Vector3(1, 1, 1), 0.20)

# ── trick area ────────────────────────────────────────────────────────────────

func _clear_trick_visual() -> void:
	for pid in _trick_cards:
		var node = _trick_cards[pid]
		if is_instance_valid(node):
			node.queue_free()
	_trick_cards.clear()

## Spawns/moves a card to the trick slot for player pid.
func _place_card_in_trick(pid: int, card_res, from_hand_idx: int) -> void:
	var dest: Vector3 = TRICK_SLOTS[pid]

	# For human: animate the card from hand
	if from_hand_idx >= 0 and from_hand_idx < _hand_cards.size():
		var hand_node: Node3D = _hand_cards[from_hand_idx]
		if is_instance_valid(hand_node):
			# Swap from hand-play handler to inspect-only handler
			if _hand_callbacks.has(hand_node):
				var cb = _hand_callbacks[hand_node]
				if hand_node.clicked.is_connected(cb):
					hand_node.clicked.disconnect(cb)
				_hand_callbacks.erase(hand_node)
			hand_node.set_interactive(true)
			hand_node.clicked.connect(func(cn): _on_trick_card_inspect(cn))
			_hand_cards.remove_at(from_hand_idx)
			_reposition_hand_after_remove(from_hand_idx)
			hand_node.slide_to(dest, 0.35)
			_trick_cards[pid] = hand_node
			return

	# For bots: spawn a new card at bot's area and slide to slot
	var node: Node3D = CardNode3D.new()
	add_child(node)
	node.setup(card_res, false)
	node.global_position = _bot_spawn_pos(pid)
	node.scale = Vector3(0.7, 0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(1, 1, 1), 0.15)
	node.slide_to(dest, 0.38, true)   # flip during slide
	_trick_cards[pid] = node
	node.set_interactive(true)
	node.clicked.connect(func(cn): _on_trick_card_inspect(cn))

func _bot_spawn_pos(pid: int) -> Vector3:
	match pid:
		1: return Vector3(-4.5, 0.3, 0.0)   # P1 west
		2: return Vector3(0.0, 0.3, -4.5)
		3: return Vector3(4.5, 0.3, 0.0)    # P3 east
	return DECK_POS

func _reposition_hand_after_remove(removed_idx: int) -> void:
	var n: int = _hand_cards.size()
	if n == 0:
		return
	var total_width: float = (n - 1) * HAND_SPACING
	var start_x: float = -total_width * 0.5
	for i in range(n):
		if is_instance_valid(_hand_cards[i]):
			var tw := create_tween()
			tw.tween_property(_hand_cards[i], "position:x", start_x + i * HAND_SPACING, 0.15)

## Slides all trick cards off to the winner's collection corner.
func _slide_trick_to_winner(winner_id: int) -> void:
	var dest: Vector3 = COLLECT_POS[winner_id % 4]
	for pid in _trick_cards:
		var node = _trick_cards[pid]
		if is_instance_valid(node):
			node.slide_off(dest, 0.45)
	_trick_cards.clear()

# ── helper: find which hand index belongs to a card resource ─────────────────

func _hand_index_for_card(card_res) -> int:
	var human = _get_human()
	if not human:
		return -1
	# The hand was already modified by play_card() before the signal fires,
	# so the card is no longer in human.hand. We match by the visual node
	# order — the node at index i represents the card that was at index i
	# before the removal. The model removes the card at the chosen index,
	# so we track the last human play index via _pending_human_idx.
	return _pending_human_idx

var _pending_human_idx: int = -1  # set by _on_hand_card_clicked before play

func _on_hand_card_clicked(idx: int) -> void:
	_pending_human_idx = idx
	_set_hand_interactive(false)
	if _gm:
		_gm.human_play(idx)

## Briefly lifts and scales a trick card so the player can read it.
func _on_trick_card_inspect(card_node: Node3D) -> void:
	if card_node.scale.x > 1.1:
		return  # tween already running
	card_node.set_interactive(false)
	var orig_y: float = card_node.position.y
	var tw := card_node.create_tween()
	tw.tween_property(card_node, "scale", Vector3(2.4, 1.0, 2.4), 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(card_node, "position:y", orig_y + 0.45, 0.18) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.65)
	tw.tween_property(card_node, "scale", Vector3.ONE, 0.18) \
		.set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card_node, "position:y", orig_y, 0.18) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(card_node):
			card_node.position.y = orig_y
			card_node.set_interactive(true)
	)

# ── stich counts ──────────────────────────────────────────────────────────────

func _update_stich_counts() -> void:
	if not _gm or _stich_labels.is_empty():
		return
	var counts: Dictionary = {}
	for p in _gm.players:
		counts[p.id] = 0
	for t in _gm.trick_history:
		var w: int = t.get("winner", -1)
		if w >= 0:
			counts[w] = counts.get(w, 0) + 1
	for i in range(_stich_labels.size()):
		var is_human: bool = (i < _gm.players.size() and not _gm.players[i].is_bot)
		var nm: String = "Du" if is_human else ("P%d" % i)
		_stich_labels[i].text = "%s: %d ★" % [nm, counts.get(i, 0)]

func _refresh_status() -> void:
	if not _gm or _gm.players.is_empty():
		return
	var cur: int = _gm.current_player_index
	var who: String = "DU" if not _gm.players[cur].is_bot else ("Bot P%d" % cur)
	_status_lbl.text = "Zug: %s  |  Stiche: %d" % [who, _gm.trick_history.size()]

# ── signal handlers ───────────────────────────────────────────────────────────

func _on_round_started() -> void:
	_clear_trick_visual()
	_update_stich_counts()
	_info_lbl.text = "Neue Runde — viel Glück!"
	_scores_lbl.text = ""
	_animate_deal()
	_refresh_status()

func _on_card_played(pid: int, card_res) -> void:
	# Determine hand index: for human we stored it in _pending_human_idx
	var hidx: int = _pending_human_idx if pid == 0 else -1
	_place_card_in_trick(pid, card_res, hidx)
	if pid == 0:
		_pending_human_idx = -1
	_refresh_status()

func _on_trick_completed(winner_id: int) -> void:
	var is_human: bool = (winner_id < _gm.players.size() and not _gm.players[winner_id].is_bot)
	var who: String = "DU" if is_human else ("Bot P%d" % winner_id)
	_info_lbl.text = "Stich → %s  (%.0f s…)" % [who, _gm.TRICK_PAUSE_DURATION]
	_last_trick_btn.disabled = false
	_update_stich_counts()
	# Cache last trick for the overlay
	_last_trick_data.clear()
	for entry in _gm.last_trick:
		_last_trick_data.append(entry.duplicate())

func _on_trick_pause_ended() -> void:
	_slide_trick_to_winner(_gm.last_trick_winner)
	_refresh_status()
	_update_stich_counts()

func _on_human_turn(_hand: Array) -> void:
	_status_lbl.text = "DEIN ZUG — Karte klicken!"
	# Rebuild hand to sync indices with current model hand after bots played
	_build_hand_from_model(true)

func _on_round_ended(scores: Dictionary) -> void:
	_status_lbl.text = "Runde vorbei!"
	_set_hand_interactive(false)
	var team_members: Dictionary = {}
	for p in _gm.players:
		if not team_members.has(p.team):
			team_members[p.team] = []
		team_members[p.team].append("Du" if not p.is_bot else "Bot P%d" % p.id)
	var txt := ""
	for tid in team_members:
		var label: String = "Re" if tid == 0 else "Kontra"
		txt += "%s [%s]: %d Pkt\n" % [label, ", ".join(team_members[tid]), scores.get(tid, 0)]
	_scores_lbl.text = txt.strip_edges()
	_info_lbl.text = "Spiel beendet. Ergebnis oben."

func _on_play_rejected(reason: String) -> void:
	_info_lbl.text = "⚠ " + reason
	_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(_info_lbl):
		_info_lbl.remove_theme_color_override("font_color")
		if _info_lbl.text.begins_with("⚠"):
			_info_lbl.text = ""

func _on_last_trick_btn() -> void:
	if _last_trick_data.is_empty():
		return
	var w_id: int = _gm.last_trick_winner
	if w_id >= 0 and w_id < _gm.players.size():
		var is_human: bool = not _gm.players[w_id].is_bot
		_last_trick_winner_lbl.text = "Gewinner: %s" % \
			("DU (P%d)" % w_id if is_human else "Bot P%d" % w_id)
	else:
		_last_trick_winner_lbl.text = ""
	for ch in _last_trick_cards_row.get_children():
		ch.queue_free()

	for ei in range(_last_trick_data.size()):
		var entry = _last_trick_data[ei]
		var pid: int = entry["player_id"]
		var card = entry["card"]
		var is_lead: bool = (ei == 0)
		var col: Color = SUIT_COL_2D.get(card.suit, Color(0.2, 0.2, 0.2))
		var panel := PanelContainer.new()
		var sfb := StyleBoxFlat.new()
		sfb.bg_color = col
		sfb.border_color = Color(1.0,0.82,0.1) if is_lead else Color(0.8,0.8,0.8)
		sfb.set_border_width_all(2 if not is_lead else 3)
		sfb.corner_radius_top_left = 6; sfb.corner_radius_top_right = 6
		sfb.corner_radius_bottom_left = 6; sfb.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", sfb)
		panel.custom_minimum_size = Vector2(88, 110)
		var sym: String = SUIT_SYM.get(card.suit, "?")
		var rk: String = RANK_NAME.get(card.rank, str(card.rank))
		var lbl := Label.new()
		lbl.text = "%sP%d\n%s %s" % ["★ " if is_lead else "", pid, rk, sym]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color.WHITE)
		panel.add_child(lbl)
		_last_trick_cards_row.add_child(panel)
	_last_trick_overlay.show()
