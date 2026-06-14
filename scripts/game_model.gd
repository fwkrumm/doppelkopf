extends Node
class_name GameModel

signal round_started
signal trick_completed(winner_id)
signal trick_pause_ended
signal round_ended(scores)
signal human_turn_started(hand: Array)
signal card_played(player_id: int, card)
signal play_rejected(reason: String)

var Ruleset = preload("res://scripts/ruleset.gd")
var Deck = preload("res://scripts/deck.gd")
var Player = preload("res://scripts/player.gd")
var Scoring = preload("res://scripts/scoring.gd")
var HeuristicAgent = preload("res://scripts/ai/heuristic_agent.gd")

var ruleset = null
var deck = null
var players: Array = []
var agents: Dictionary = {}
var current_player_index: int = 0
var trick: Array = []
var last_trick: Array = []      # copy of most recently completed trick
var last_trick_winner: int = -1
var trick_history: Array = []
var round_active: bool = false
var waiting_for_human: bool = false
var _turn_acc: float = 0.0
var turn_delay: float = 1.0     # seconds between bot plays

# Stille Hochzeit tracking: one player holds both Queens of Clubs.
# The holder is Re (team=1); the first trick won by any other player
# reveals them as the Re partner.
var _hochzeit_active: bool = false
var _hochzeit_holder_id: int = -1

var _trick_pausing: bool = false
var _trick_pause_timer: float = 0.0
const TRICK_PAUSE_DURATION: float = 2.5

func _init():
    pass

func start_game(rules_path: String = "res://rules/default_rules.json", num_players: int = 4, human_seat: int = 0) -> void:
    ruleset = Ruleset.new()
    ruleset.load(rules_path)
    deck = Deck.new()
    deck.build(ruleset.get_ranks(), ruleset.get_suits(), ruleset.get_copies())
    deck.shuffle()
    setup_players(num_players, human_seat)
    deal()
    assign_teams()
    current_player_index = 0
    trick = []
    last_trick = []
    last_trick_winner = -1
    trick_history = []
    round_active = true
    _turn_acc = 0.0
    _trick_pausing = false
    _trick_pause_timer = 0.0
    set_process(true)
    emit_signal("round_started")

func setup_players(num_players: int = 4, human_seat: int = 0) -> void:
    players.clear()
    agents.clear()
    for i in range(num_players):
        var p = Player.new()
        p.id = i
        p.name = "Player %d" % i
        p.seat = i
        p.is_bot = (i != human_seat)
        p.team = i % 2
        p.score = 0
        p.collected = []
        players.append(p)
    for p in players:
        if p.is_bot:
            agents[p.id] = HeuristicAgent.new()

## Assign Re/Kontra teams based on who holds the Queens of Clubs (Kreuz-Dame).
## Normal: the two holders are Re (team=1), the other two are Kontra (team=0).
## Stille Hochzeit: one holder has both Queens — they are Re solo until another
## player wins a trick, at which point that player becomes the Re partner.
func assign_teams() -> void:
    _hochzeit_active = false
    _hochzeit_holder_id = -1
    var re_ids: Array = []
    var both_holder_id: int = -1
    for p in players:
        var n := 0
        for c in p.hand:
            if c.suit == "CLUBS" and c.rank == 12:
                n += 1
        if n == 2:
            both_holder_id = p.id
        if n > 0:
            re_ids.append(p.id)
    if re_ids.size() == 2 and both_holder_id == -1:
        # Normal: each Re player holds exactly one Queen of Clubs.
        for p in players:
            p.team = 1 if p.id in re_ids else 0
    elif both_holder_id != -1:
        # Stille Hochzeit: one player holds both Queens.
        for p in players:
            p.team = 1 if p.id == both_holder_id else 0
        _hochzeit_active = true
        _hochzeit_holder_id = both_holder_id
    else:
        # Unexpected distribution (e.g. custom deck) — fall back to alternating.
        for i in range(players.size()):
            players[i].team = i % 2

func deal() -> void:
    for p in players:
        p.clear_hand()
    var cards_per_player = int(deck.size() / players.size())
    for i in range(cards_per_player):
        for p in players:
            var c = deck.draw()
            if c:
                p.receive_card(c)

func _process(delta: float) -> void:
    if not round_active:
        set_process(false)
        return
    if _trick_pausing:
        _trick_pause_timer -= delta
        if _trick_pause_timer <= 0.0:
            _trick_pausing = false
            trick.clear()
            emit_signal("trick_pause_ended")
        return
    # Only end the round once the current trick is cleared AND all hands are empty
    if trick.is_empty():
        var all_empty := true
        for p in players:
            if not p.hand.is_empty():
                all_empty = false
                break
        if all_empty:
            _end_round()
            return
    if waiting_for_human:
        return
    _turn_acc += delta
    if _turn_acc < turn_delay:
        return
    _turn_acc = 0.0
    var p = players[current_player_index]
    if p.is_bot:
        var agent = agents.get(p.id, null)
        if agent:
            var choice = agent.choose_card(p.hand, self)
            var idx = choice.get("index", 0)
            play_card(p.id, idx)
        else:
            play_card(p.id, 0)
    else:
        waiting_for_human = true
        emit_signal("human_turn_started", players[current_player_index].hand.duplicate())

func _end_round() -> void:
    round_active = false
    waiting_for_human = false
    var scoring = Scoring.new()
    var scores = scoring.compute_round_scores(trick_history, ruleset, players)
    emit_signal("round_ended", scores)
    persist_round(scores)

func play_card(player_id: int, card_index: int) -> bool:
    var p = get_player_by_id(player_id)
    if p == null:
        return false
    if card_index < 0 or card_index >= p.hand.size():
        return false
    var played_card
    if trick.size() > 0:
        var lead_eff_suit: String = ruleset.get_effective_suit(trick[0]["card"])
        var candidate = p.hand[card_index]
        var cand_eff_suit: String = ruleset.get_effective_suit(candidate)
        if cand_eff_suit != lead_eff_suit and _has_effective_suit(p, lead_eff_suit):
            # must follow suit — use first legal card
            played_card = null
            for i in range(p.hand.size()):
                if ruleset.get_effective_suit(p.hand[i]) == lead_eff_suit:
                    played_card = p.play_card(i)
                    break
            if played_card == null:
                played_card = p.play_card(card_index)
        else:
            played_card = p.play_card(card_index)
    else:
        played_card = p.play_card(card_index)
    trick.append({ "player_id": player_id, "card": played_card })
    emit_signal("card_played", player_id, played_card)
    current_player_index = (current_player_index + 1) % players.size()
    if trick.size() == players.size():
        var winner_id = evaluate_trick()
        var winner = get_player_by_id(winner_id)
        if winner:
            var collected = []
            for e in trick:
                collected.append(e["card"])
            winner.collected.append_array(collected)
            trick_history.append({ "cards": trick.duplicate(true), "winner": winner_id })
        last_trick = trick.duplicate(true)
        last_trick_winner = winner_id
        current_player_index = index_of_player(winner_id)
        # Stille Hochzeit: first trick NOT won by the holder reveals the Re partner.
        if _hochzeit_active and winner_id != _hochzeit_holder_id:
            var partner = get_player_by_id(winner_id)
            if partner:
                partner.team = 1
            _hochzeit_active = false
        emit_signal("trick_completed", winner_id)
        _trick_pausing = true
        _trick_pause_timer = TRICK_PAUSE_DURATION
    return true

func evaluate_trick() -> int:
    if trick.size() == 0:
        return -1
    var lead_eff_suit: String = ruleset.get_effective_suit(trick[0]["card"])
    var winning = trick[0]
    for i in range(1, trick.size()):
        var e = trick[i]
        if _beats_winner(e["card"], winning["card"], lead_eff_suit):
            winning = e
    return int(winning["player_id"])

## Returns true if challenger beats the current winning card given the lead effective suit.
func _beats_winner(challenger, current_winner, lead_eff_suit: String) -> bool:
    var c_trump: bool = ruleset.is_trump(challenger)
    var w_trump: bool = ruleset.is_trump(current_winner)
    if c_trump and not w_trump:
        return true
    if not c_trump and w_trump:
        return false
    if c_trump and w_trump:
        return ruleset.get_trump_order(challenger) > ruleset.get_trump_order(current_winner)
    # Both non-trump: off-suit never wins
    var c_eff: String = ruleset.get_effective_suit(challenger)
    if c_eff != lead_eff_suit:
        return false
    var w_eff: String = ruleset.get_effective_suit(current_winner)
    if w_eff != lead_eff_suit:
        return true
    return ruleset.get_suit_order(challenger) > ruleset.get_suit_order(current_winner)

## Checks if the player has any card whose effective suit matches eff_suit.
func _has_effective_suit(player_obj, eff_suit: String) -> bool:
    for c in player_obj.hand:
        if ruleset.get_effective_suit(c) == eff_suit:
            return true
    return false

func has_suit(player_obj, suit: String) -> bool:
    return _has_effective_suit(player_obj, suit)

func get_player_by_id(id: int):
    for p in players:
        if p.id == id:
            return p
    return null

func index_of_player(id: int) -> int:
    for i in range(players.size()):
        if players[i].id == id:
            return i
    return 0

## Validates and executes the human player's card choice. Emits play_rejected if illegal.
func human_play(card_index: int) -> bool:
    if not waiting_for_human:
        return false
    var p = players[current_player_index]
    if card_index < 0 or card_index >= p.hand.size():
        return false
    if trick.size() > 0:
        var lead_eff_suit: String = ruleset.get_effective_suit(trick[0]["card"])
        var cand_eff_suit: String = ruleset.get_effective_suit(p.hand[card_index])
        if cand_eff_suit != lead_eff_suit and _has_effective_suit(p, lead_eff_suit):
            var suit_label: String = "Trumpf" if lead_eff_suit == "TRUMP" else lead_eff_suit.capitalize()
            emit_signal("play_rejected", "Farbe bekennen! Du musst %s spielen." % suit_label)
            return false
    waiting_for_human = false
    _turn_acc = 0.0
    return play_card(p.id, card_index)

func persist_round(scores: Dictionary) -> void:
    var dir = "user://saves"
    var base = DirAccess.open("user://")
    if base:
        if not base.dir_exists("saves"):
            base.make_dir_recursive("saves")
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    var ts = rng.randi()
    var fname = "%s/round_%d.json" % [dir, ts]
    var f = FileAccess.open(fname, FileAccess.WRITE)
    if f:
        var out = { "scores": scores, "history": trick_history, "rules": ruleset.data }
        # store as Variant (fast, safe). File will not be human-readable JSON.
        f.store_var(out)
        f.close()
