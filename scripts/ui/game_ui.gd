extends Control

var _gm: Node = null

var _status_lbl: Label = null
var _scores_lbl: Label = null
var _info_lbl: Label = null
var _trick_panels: Array = []    # PanelContainers, indexed by player_id
var _trick_labels: Array = []    # Labels inside each trick panel
var _hand_container: HBoxContainer = null
var _last_trick_btn: Button = null
var _last_trick_overlay: Control = null
var _last_trick_cards_row: HBoxContainer = null
var _last_trick_winner_lbl: Label = null
var _stich_count_labels: Array = []

# Called by main.gd after adding to scene tree
func setup(game_model: Node) -> void:
	_gm = game_model
	_gm.round_started.connect(_on_round_started)
	_gm.card_played.connect(_on_card_played)
	_gm.trick_completed.connect(_on_trick_completed)
	_gm.trick_pause_ended.connect(_on_trick_pause_ended)
	_gm.round_ended.connect(_on_round_ended)
	_gm.human_turn_started.connect(_on_human_turn)
	_gm.play_rejected.connect(_on_play_rejected)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Status row
	_status_lbl = Label.new()
	_status_lbl.text = "Doppelkopf — starting…"
	_status_lbl.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(_status_lbl)

	# Scores row
	_scores_lbl = Label.new()
	_scores_lbl.text = ""
	_scores_lbl.custom_minimum_size = Vector2(0, 22)
	vbox.add_child(_scores_lbl)

	vbox.add_child(HSeparator.new())

	# Trick header row + last stich button
	var trick_hdr_row := HBoxContainer.new()
	vbox.add_child(trick_hdr_row)

	var trick_hdr := Label.new()
	trick_hdr.text = "Current trick:"
	trick_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trick_hdr_row.add_child(trick_hdr)

	_last_trick_btn = Button.new()
	_last_trick_btn.text = "Letzter Stich"
	_last_trick_btn.disabled = true
	_last_trick_btn.pressed.connect(_on_last_trick_pressed)
	trick_hdr_row.add_child(_last_trick_btn)

	# Per-player Stich count row
	var stich_row := HBoxContainer.new()
	stich_row.add_theme_constant_override("separation", 8)
	vbox.add_child(stich_row)
	for i in range(4):
		var cnt_lbl := Label.new()
		cnt_lbl.text = "P%d: 0 \u2605" % i
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cnt_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
		stich_row.add_child(cnt_lbl)
		_stich_count_labels.append(cnt_lbl)

	# Trick area — one panel per player
	var trick_row := HBoxContainer.new()
	trick_row.custom_minimum_size = Vector2(0, 110)
	trick_row.add_theme_constant_override("separation", 8)
	vbox.add_child(trick_row)

	for i in range(4):
		var panel := _make_card_panel(Color(0.18, 0.28, 0.18, 1.0))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := Label.new()
		lbl.text = "P%d\n—" % i
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(lbl)
		trick_row.add_child(panel)
		_trick_panels.append(panel)
		_trick_labels.append(lbl)

	# Info line
	_info_lbl = Label.new()
	_info_lbl.text = ""
	_info_lbl.custom_minimum_size = Vector2(0, 22)
	vbox.add_child(_info_lbl)

	vbox.add_child(HSeparator.new())

	# Flexible spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Hand header
	var hand_hdr := Label.new()
	hand_hdr.text = "Your hand (click to play):"
	vbox.add_child(hand_hdr)

	# Scrollable hand row
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 96)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_hand_container = HBoxContainer.new()
	_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_hand_container)

	# Last trick overlay (hidden by default)
	_last_trick_overlay = _build_last_trick_overlay()
	add_child(_last_trick_overlay)
	_last_trick_overlay.hide()

# ── last stich overlay ────────────────────────────────────────────────

func _build_last_trick_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 10
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
	panel.custom_minimum_size = Vector2(480, 220)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Letzter Stich"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_last_trick_winner_lbl = Label.new()
	_last_trick_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_trick_winner_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1, 1.0))
	vbox.add_child(_last_trick_winner_lbl)

	_last_trick_cards_row = HBoxContainer.new()
	_last_trick_cards_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_last_trick_cards_row)

	var close_btn := Button.new()
	close_btn.text = "Schließen"
	close_btn.pressed.connect(func(): overlay.hide())
	vbox.add_child(close_btn)

	return overlay

# ── style factories ───────────────────────────────────────────────────

## Creates a StyleBoxFlat with rounded corners and drop shadow.
func _make_card_style(col: Color, border_col: Color = Color(0.8, 0.8, 0.8, 1.0), border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_border_width_all(border_w)
	s.border_color = border_col
	s.corner_radius_top_left = 7
	s.corner_radius_top_right = 7
	s.corner_radius_bottom_left = 7
	s.corner_radius_bottom_right = 7
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 4
	return s

func _make_card_panel(col: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_card_style(col))
	return panel

## Maps suit to a rich background colour.
func _suit_color(suit: String) -> Color:
	match suit:
		"HEARTS":   return Color(0.68, 0.12, 0.12, 1.0)
		"DIAMONDS": return Color(0.72, 0.26, 0.05, 1.0)
		"CLUBS":    return Color(0.08, 0.18, 0.42, 1.0)
		"SPADES":   return Color(0.10, 0.10, 0.22, 1.0)
		_:          return Color(0.22, 0.22, 0.22, 1.0)

# ── card display helpers ──────────────────────────────────────────────

const SUIT_SYM: Dictionary = {"CLUBS": "♣", "SPADES": "♠", "HEARTS": "♥", "DIAMONDS": "♦"}
const RANK_NAME: Dictionary = {9: "9", 10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"}

func _card_text(card) -> String:
	var s: String = SUIT_SYM.get(card.suit, card.suit)
	var r: String = RANK_NAME.get(card.rank, str(card.rank))
	return "%s\n%s" % [r, s]

# ── trick area ────────────────────────────────────────────────────────

func _reset_trick_slots() -> void:
	for i in range(4):
		var style := _make_card_style(Color(0.18, 0.28, 0.18, 1.0))
		_trick_panels[i].add_theme_stylebox_override("panel", style)
		_trick_labels[i].text = "P%d\n—" % i
		_trick_labels[i].remove_theme_color_override("font_color")
		_trick_panels[i].scale = Vector2(1, 1)
		_trick_panels[i].modulate = Color(1, 1, 1, 1)

## Displays a played card in the trick slot with optional 3D-flip animation.
func _show_trick_card(pid: int, card, is_lead: bool, animate: bool) -> void:
	var prefix: String = "★ " if is_lead else ""
	_trick_labels[pid].text = "%sP%d\n%s" % [prefix, pid, _card_text(card)]
	_trick_labels[pid].add_theme_color_override("font_color", Color.WHITE)
	var border_col: Color = Color(1.0, 0.82, 0.1, 1.0) if is_lead else Color(0.85, 0.85, 0.85, 1.0)
	var border_w: int = 3 if is_lead else 2
	var style := _make_card_style(_suit_color(card.suit), border_col, border_w)
	_trick_panels[pid].add_theme_stylebox_override("panel", style)
	if animate:
		_animate_flip(_trick_panels[pid])

## Simulates a 3D card-flip: collapses horizontally then springs back with a bright flash.
## Uses await so the panel is fully laid out before we read its size for pivot_offset.
func _animate_flip(panel: Control) -> void:
	# Hide immediately so the card doesn't flash its new style before the animation starts
	panel.scale = Vector2(0.0, 1.0)
	panel.modulate = Color(1.5, 1.5, 1.5, 0.0)
	# Wait one frame for the layout engine to assign panel.size
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size / 2.0
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)
	tw.parallel().tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.40).set_ease(Tween.EASE_OUT)

# ── hand ──────────────────────────────────────────────────────────────

func _get_human() -> Object:
	if not _gm:
		return null
	for p in _gm.players:
		if not p.is_bot:
			return p
	return null

func _rebuild_hand(enabled: bool) -> void:
	for c in _hand_container.get_children():
		c.queue_free()
	var human := _get_human()
	if not human:
		return
	for i in range(human.hand.size()):
		var card = human.hand[i]
		var suit: String = card.suit
		var col: Color = _suit_color(suit) if enabled else Color(0.28, 0.28, 0.28, 1.0)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(68, 82)
		btn.text = _card_text(card)
		btn.disabled = not enabled
		btn.add_theme_stylebox_override("normal", _make_card_style(col))
		btn.add_theme_stylebox_override("hover", _make_card_style(col.lightened(0.22)))
		btn.add_theme_stylebox_override("pressed", _make_card_style(col.darkened(0.2)))
		btn.add_theme_stylebox_override("disabled", _make_card_style(Color(0.28, 0.28, 0.28, 1.0)))
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 1.0))

		var idx := i
		btn.pressed.connect(func(): _on_card_btn(idx))

		if enabled:
			btn.mouse_entered.connect(func():
				var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12)
			)
			btn.mouse_exited.connect(func():
				var tw := create_tween().set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
			)

		_hand_container.add_child(btn)

# ── status ────────────────────────────────────────────────────────────

func _refresh_status() -> void:
	if not _gm or _gm.players.is_empty():
		return
	var cur: int = _gm.current_player_index
	var who: String = "YOU" if not _gm.players[cur].is_bot else ("Bot P%d" % cur)
	_status_lbl.text = "Turn: %s  |  Tricks: %d" % [who, _gm.trick_history.size()]

# ── signal handlers ───────────────────────────────────────────────────

func _on_round_started() -> void:
	_info_lbl.text = "Neue Runde — viel Glück!"
	_scores_lbl.text = ""
	_reset_trick_slots()
	_rebuild_hand(false)
	_refresh_status()
	_update_stich_counts()

func _on_card_played(pid: int, card) -> void:
	var is_lead: bool = (_gm.trick.size() == 1)
	_show_trick_card(pid, card, is_lead, true)
	_refresh_status()

func _on_trick_completed(winner_id: int) -> void:
	var is_human_win: bool = (winner_id < _gm.players.size() and not _gm.players[winner_id].is_bot)
	var who: String = "DU" if is_human_win else ("Bot P%d" % winner_id)
	_info_lbl.text = "Stich \u2192 %s  (%.0f s\u2026)" % [who, _gm.TRICK_PAUSE_DURATION]
	_last_trick_btn.disabled = false
	_update_stich_counts()
	_rebuild_hand(false)

func _on_trick_pause_ended() -> void:
	_reset_trick_slots()
	_refresh_status()
	_update_stich_counts()

func _on_human_turn(_hand: Array) -> void:
	_status_lbl.text = "DEIN ZUG — Karte klicken"
	_rebuild_hand(true)

func _on_round_ended(scores: Dictionary) -> void:
	_status_lbl.text = "Runde vorbei!"
	# Build team → member name lists
	var team_members: Dictionary = {}
	for p in _gm.players:
		if not team_members.has(p.team):
			team_members[p.team] = []
		var pname: String = "Du" if not p.is_bot else ("Bot P%d" % p.id)
		team_members[p.team].append(pname)
	var txt := ""
	for team_id in team_members:
		var pts: int = scores.get(team_id, 0)
		var label: String = "Re" if team_id == 0 else "Kontra"
		txt += "%s [%s]: %d Pkt\n" % [label, ", ".join(team_members[team_id]), pts]
	_scores_lbl.text = txt.strip_edges()
	_info_lbl.text = "Spiel beendet. Ergebnis oben."
	_rebuild_hand(false)

func _on_card_btn(idx: int) -> void:
	if _gm:
		_gm.human_play(idx)

func _on_last_trick_pressed() -> void:
	if not _gm or _gm.last_trick.is_empty():
		return
	var w_id: int = _gm.last_trick_winner
	if w_id >= 0 and w_id < _gm.players.size():
		var is_human_win: bool = not _gm.players[w_id].is_bot
		_last_trick_winner_lbl.text = "Gewinner: %s" % ("DU (P%d)" % w_id if is_human_win else "Bot P%d" % w_id)
	else:
		_last_trick_winner_lbl.text = ""
	for c in _last_trick_cards_row.get_children():
		c.queue_free()
	for entry_idx in range(_gm.last_trick.size()):
		var entry = _gm.last_trick[entry_idx]
		var pid: int = entry["player_id"]
		var card = entry["card"]
		var is_lead: bool = (entry_idx == 0)
		var col: Color = _suit_color(card.suit)
		var border_col: Color = Color(1.0, 0.82, 0.1, 1.0) if is_lead else Color(0.85, 0.85, 0.85, 1.0)
		var panel := _make_card_panel(col)
		panel.add_theme_stylebox_override("panel", _make_card_style(col, border_col, 3 if is_lead else 2))
		panel.custom_minimum_size = Vector2(90, 110)
		var lbl := Label.new()
		lbl.text = "%sP%d\n%s" % ["★ " if is_lead else "", pid, _card_text(card)]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color.WHITE)
		panel.add_child(lbl)
		_last_trick_cards_row.add_child(panel)
	_last_trick_overlay.show()

## Recomputes and displays each player's Stich count from trick_history.
func _update_stich_counts() -> void:
	if not _gm or _stich_count_labels.is_empty():
		return
	var counts: Dictionary = {}
	for p in _gm.players:
		counts[p.id] = 0
	for t in _gm.trick_history:
		var w: int = t.get("winner", -1)
		if w >= 0:
			counts[w] = counts.get(w, 0) + 1
	for i in range(_stich_count_labels.size()):
		var is_human: bool = (i < _gm.players.size() and not _gm.players[i].is_bot)
		var name_str: String = "Du" if is_human else ("P%d" % i)
		_stich_count_labels[i].text = "%s: %d \u2605" % [name_str, counts.get(i, 0)]

## Flashes a red warning when the human attempts an illegal card play.
func _on_play_rejected(reason: String) -> void:
	_info_lbl.text = "\u26a0 " + reason
	_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 1.0))
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(_info_lbl):
		_info_lbl.remove_theme_color_override("font_color")
		if _info_lbl.text.begins_with("\u26a0"):
			_info_lbl.text = ""
