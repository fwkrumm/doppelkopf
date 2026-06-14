extends RefCounted
class_name HeuristicAgent

# Simple rule-based agent. Chooses legal card using basic heuristics.

func choose_card(player_hand: Array, game_state) -> Dictionary:
	if player_hand.is_empty():
		return {}
	var lead_eff_suit: String = ""
	if game_state.trick.size() > 0:
		lead_eff_suit = game_state.ruleset.get_effective_suit(game_state.trick[0]["card"])
	# Follow effective suit if possible
	if lead_eff_suit != "":
		for i in range(player_hand.size()):
			if game_state.ruleset.get_effective_suit(player_hand[i]) == lead_eff_suit:
				return { "index": i }
	# Leading or can't follow: discard lowest-point card
	var best_idx := 0
	var best_points := 999999
	for i in range(player_hand.size()):
		var pts: int = game_state.ruleset.get_point_for_rank(player_hand[i].rank)
		if pts < best_points:
			best_points = pts
			best_idx = i
	return { "index": best_idx }
