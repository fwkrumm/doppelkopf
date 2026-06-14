extends RefCounted
class_name Player

var id: int = -1
var name: String = ""
var seat: int = -1
var is_bot: bool = false
var hand: Array = []
var team: int = -1
var score: int = 0
var collected: Array = []

func _init(_id: int = -1, _name: String = "", _seat: int = -1, _is_bot: bool = false):
    id = _id
    name = _name
    seat = _seat
    is_bot = _is_bot
    hand = []
    team = seat % 2 if seat >= 0 else -1
    score = 0
    collected = []

func receive_card(card) -> void:
    hand.append(card)

func play_card(index: int):
    if index < 0 or index >= hand.size():
        return null
    var card = hand[index]
    hand.remove_at(index)
    return card

func clear_hand() -> void:
    hand.clear()
