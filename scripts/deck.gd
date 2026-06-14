extends RefCounted
class_name Deck

var cards: Array = []
var CardClass = preload("res://scripts/card.gd")

func build(ranks: Array, suits: Array, copies: int = 1) -> void:
    cards.clear()
    var uid = 0
    for c in range(copies):
        for s in suits:
            for r in ranks:
                var card = CardClass.new()
                card.suit = s
                card.rank = r
                card.uid = uid
                uid += 1
                cards.append(card)

func shuffle() -> void:
    cards.shuffle()

func draw():
    if cards.is_empty():
        return null
    return cards.pop_back()

func size() -> int:
    return cards.size()

func to_array() -> Array:
    return cards.duplicate(true)
