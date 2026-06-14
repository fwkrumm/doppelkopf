extends Node

func _ready():
    var d = {"a": 1, "b": [1,2,3]}
    print("call d.to_json() ->")
    print(d.to_json())
    get_tree().quit()
