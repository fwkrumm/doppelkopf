extends Node

func _ready():
    var gm = preload("res://scripts/game_model.gd").new()
    gm.start_game()
    # set up a controlled trick
    var p0 = gm.get_player_by_id(0)
    var p1 = gm.get_player_by_id(1)
    var card_class = preload("res://scripts/card.gd")
    var c1 = card_class.new("HEARTS", 14, 100)
    var c2 = card_class.new("HEARTS", 10, 101)
    var c3 = card_class.new("CLUBS", 15, 102)
    # simulate trick
    gm.trick = []
    gm.trick.append({"player_id":0, "card": c1})
    gm.trick.append({"player_id":1, "card": c2})
    gm.trick.append({"player_id":2, "card": c3})
    var winner = gm.evaluate_trick()
    if winner != 0:
        push_error("test_trick: expected winner 0 got %s" % str(winner))
    else:
        print("test_trick: ok")
    get_tree().quit(0)
