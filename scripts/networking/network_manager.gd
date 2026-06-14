extends Node

"""
NetworkManager: thin wrapper to manage ENet + MCP stubs and provide a simple API
to the rest of the game. Instantiate this node (or autoload it) and call
`start_host()`, `start_client()`, or `start_mcp()` as needed.
"""

@onready var ENetStub = preload("res://scripts/networking/enet_stub.gd")
@onready var MCPStub = preload("res://scripts/networking/mcp_stub.gd")

var enet_node: Node = null
var mcp_node: Node = null

func _ready() -> void:
    # keep nodes ready but don't auto-start
    enet_node = ENetStub.new()
    enet_node.name = "ENetStub"
    add_child(enet_node)
    enet_node.connect("connected", Callable(self, "_on_enet_connected"))
    enet_node.connect("disconnected", Callable(self, "_on_enet_disconnected"))

    mcp_node = MCPStub.new()
    mcp_node.name = "MCPStub"
    add_child(mcp_node)
    mcp_node.connect("bot_message", Callable(self, "_on_mcp_bot_message"))

func start_host(port: int = 12345, max_clients: int = 4) -> bool:
    return enet_node.start_server(port, max_clients)

func start_client(host: String, port: int = 12345) -> bool:
    return enet_node.connect_to_server(host, port)

func stop_network() -> void:
    enet_node.stop()
    mcp_node.stop()

func start_mcp(port: int = 5000) -> bool:
    return mcp_node.start(port)

func _on_enet_connected(peer_id):
    print("NetworkManager: ENet connected", peer_id)

func _on_enet_disconnected(peer_id):
    print("NetworkManager: ENet disconnected", peer_id)

func _on_mcp_bot_message(parsed):
    print("NetworkManager: MCP bot message:", parsed)
    # TODO: dispatch to game model or bot manager
