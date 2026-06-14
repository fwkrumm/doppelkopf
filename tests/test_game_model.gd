extends Node

func _ready():
    var gm = preload("res://scripts/game_model.gd").new()
    gm.start_game()
    if gm.deck.size() == 0:
        push_error("test_game_model: deck empty")
    else:
        print("test_game_model: ok — deck size", gm.deck.size())
    get_tree().quit(0)
