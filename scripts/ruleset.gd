extends Resource
class_name Ruleset

var data: Dictionary = {}
var default_suits = ["CLUBS","SPADES","HEARTS","DIAMONDS"]

func load(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		data = {}
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	# JSON.parse_string may return either a parse-result Dictionary {"error","result"}
	# or the parsed object directly depending on engine version. Handle both.
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("error") and parsed.has("result"):
			if parsed.error == OK:
				data = parsed.result
			else:
				data = {}
		else:
			# parsed is the data itself
			data = parsed
	else:
		data = {}

func get_suits() -> Array:
	return data.get("suits", default_suits)

func get_ranks() -> Array:
	return data.get("ranks", [])

func get_copies() -> int:
	return int(data.get("copies", 1))

func get_trump_suits() -> Array:
	return data.get("trump_suits", [])

## Returns true for all Doppelkopf trumps: J (11), Q (12), any Diamond, and Dulle (♥10).
func is_trump(card) -> bool:
	if card == null:
		return false
	var suit: String = card.suit if typeof(card) == TYPE_OBJECT else str(card.get("suit", ""))
	var rank: int = int(card.rank) if typeof(card) == TYPE_OBJECT else int(card.get("rank", 0))
	if rank == 12 or rank == 11:
		return true
	if suit == "DIAMONDS":
		return true
	if rank == 10 and suit == "HEARTS" and data.get("dulle_enabled", true):
		return true
	return false

## Returns "TRUMP" for trump cards, otherwise the card's natural suit.
func get_effective_suit(card) -> String:
	if is_trump(card):
		return "TRUMP"
	var suit: String = card.suit if typeof(card) == TYPE_OBJECT else str(card.get("suit", ""))
	return suit

## Trump ordering value — higher beats lower.
## Dulle(100) > ♣Q(90) > ♠Q(89) > ♥Q(88) > ♦Q(87) > ♣J(80) > ♠J(79) > ♥J(78) > ♦J(77) > ♦A(14) > ♦10(13) > ♦K(12).
func get_trump_order(card) -> int:
	var suit: String = card.suit if typeof(card) == TYPE_OBJECT else str(card.get("suit", ""))
	var rank: int = int(card.rank) if typeof(card) == TYPE_OBJECT else int(card.get("rank", 0))
	if rank == 10 and suit == "HEARTS" and data.get("dulle_enabled", true):
		return 100
	if rank == 12:
		var q: Dictionary = {"CLUBS": 90, "SPADES": 89, "HEARTS": 88, "DIAMONDS": 87}
		return q.get(suit, 87)
	if rank == 11:
		var j: Dictionary = {"CLUBS": 80, "SPADES": 79, "HEARTS": 78, "DIAMONDS": 77}
		return j.get(suit, 77)
	if suit == "DIAMONDS":
		var d: Dictionary = {14: 14, 10: 13, 13: 12, 9: 11}
		return d.get(rank, rank)
	return 0

## Ordering for non-trump cards within their suit: A(4) > 10(3) > K(2) > 9(1).
func get_suit_order(card) -> int:
	var rank: int = int(card.rank) if typeof(card) == TYPE_OBJECT else int(card.get("rank", 0))
	var s: Dictionary = {14: 4, 10: 3, 13: 2, 9: 1}
	return s.get(rank, rank)

func get_point_for_rank(rank) -> int:
	var scoring = data.get("scoring", {})
	var pmap = scoring.get("point_map", {})
	var key = str(rank)
	if key in pmap:
		return int(pmap[key])
	return int(scoring.get("default_point", 0))
