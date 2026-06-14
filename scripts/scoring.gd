extends RefCounted
class_name Scoring

func compute_trick_value(cards: Array, ruleset) -> int:
    var sum = 0
    for c in cards:
        sum += ruleset.get_point_for_rank(c.rank)
    return sum

func compute_round_scores(trick_history: Array, ruleset, players: Array) -> Dictionary:
    var team_points: Dictionary = {}
    for p in players:
        team_points[p.team] = 0
    for t in trick_history:
        var cards = []
        for e in t["cards"]:
            cards.append(e["card"])
        var value = compute_trick_value(cards, ruleset)
        var winner = t.get("winner", -1)
        var winner_player = null
        for p in players:
            if p.id == winner:
                winner_player = p
                break
        if winner_player != null:
            team_points[winner_player.team] = team_points.get(winner_player.team, 0) + value
    return team_points
