extends Node

func _ready():
    var gm = preload("res://scripts/game_model.gd").new()
    gm.start_game()
    var total_cards = 0
    for p in gm.players:
        total_cards += p.hand.size()
    if total_cards == 0:
        push_error("test_deal: no cards dealt")
    else:
        print("test_deal: ok - total cards", total_cards)
    get_tree().quit(0)
