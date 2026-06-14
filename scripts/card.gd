extends Resource
class_name Card

@export var suit: String = ""
@export var rank: int = 0
@export var uid: int = -1

func _init(_suit: String = "", _rank: int = 0, _uid: int = -1):
    suit = _suit
    rank = _rank
    uid = _uid

func as_text() -> String:
    return "%s:%d" % [suit, rank]
