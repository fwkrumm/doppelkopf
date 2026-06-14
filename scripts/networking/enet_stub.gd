extends Node

"""
ENet stub for Godot 4: provides helper methods to start a host or connect as a client.

This is intentionally minimal: it logs actions and exposes signals the rest of
the game can connect to. Replace stubs with full ENet logic when integrating.
"""

signal connected(peer_id)
signal disconnected(peer_id)
signal peer_connected(id)
signal peer_disconnected(id)

var peer = null

func start_server(port: int = 12345, max_clients: int = 4) -> bool:
    # Attempt to create an ENet server peer. If the API isn't available, log a warning.
    if Engine.has_singleton("ENetMultiplayerPeer"):
        peer = ENetMultiplayerPeer.new()
        var err = peer.create_server(port, max_clients)
        if err != OK:
            push_error("ENet: create_server failed: %s" % [str(err)])
            return false
        get_tree().multiplayer.multiplayer_peer = peer
        print("ENet: server started on port %d" % port)
        return true
    else:
        push_warning("ENetMultiplayerPeer not found; running in offline stub mode")
        # stub: simulate success
        call_deferred("_emit_connected_stub")
        return true

func connect_to_server(host: String, port: int = 12345) -> bool:
    if Engine.has_singleton("ENetMultiplayerPeer"):
        peer = ENetMultiplayerPeer.new()
        var err = peer.create_client(host, port)
        if err != OK:
            push_error("ENet: create_client failed: %s" % [str(err)])
            return false
        get_tree().multiplayer.multiplayer_peer = peer
        print("ENet: connecting to %s:%d" % [host, port])
        return true
    else:
        push_warning("ENetMultiplayerPeer not found; running in offline stub mode")
        call_deferred("_emit_connected_stub")
        return true

func stop() -> void:
    if peer:
        if Engine.has_singleton("ENetMultiplayerPeer"):
            get_tree().multiplayer.multiplayer_peer = null
        peer = null
    emit_signal("disconnected", 0)

func _emit_connected_stub() -> void:
    emit_signal("connected", 1)
