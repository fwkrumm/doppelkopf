extends Control

@onready var path_edit = $Panel/VBox/FileRow/PathEdit
@onready var editor = $Panel/VBox/Editor
@onready var load_btn = $Panel/VBox/FileRow/LoadBtn
@onready var save_btn = $Panel/VBox/FileRow/SaveBtn
@onready var reset_btn = $Panel/VBox/FileRow/ResetBtn

func _ready():
    load_btn.connect("pressed", Callable(self, "_on_LoadBtn_pressed"))
    save_btn.connect("pressed", Callable(self, "_on_SaveBtn_pressed"))
    reset_btn.connect("pressed", Callable(self, "_on_ResetBtn_pressed"))
    print("RulesConfig: _ready called, path:", path_edit.text)
    # initial load
    load_ruleset_to_editor(path_edit.text)

func _enter_tree():
    print("RulesConfig: enter_tree")

func _exit_tree():
    print("RulesConfig: exit_tree")

func load_ruleset_to_editor(path: String) -> void:
    var f = FileAccess.open(path, FileAccess.READ)
    if not f:
        editor.text = "{}"
        return
    var text = f.get_as_text()
    f.close()
    # keep original file text (preserve formatting)
    editor.text = text

func _on_LoadBtn_pressed() -> void:
    load_ruleset_to_editor(path_edit.text)

func _on_SaveBtn_pressed() -> void:
    var text = editor.text.strip_edges()
    var parsed = JSON.parse_string(text)
    if parsed == null:
        push_error("RulesConfig: invalid JSON, not saved")
        return
    var path = path_edit.text.strip_edges()
    if path.begins_with("res://"):
        # cannot write to res:// at runtime; save to user:// instead
        path = "user://" + path.get_file()
    if path == "":
        path = "user://rules_custom.json"
    var f = FileAccess.open(path, FileAccess.WRITE)
    if not f:
        push_error("RulesConfig: failed opening file for write: %s" % path)
        return
    # write editor text as-is (validated JSON)
    f.store_string(text)
    f.close()
    print("RulesConfig: saved:", path)

func _on_ResetBtn_pressed() -> void:
    load_ruleset_to_editor("res://rules/default_rules.json")
