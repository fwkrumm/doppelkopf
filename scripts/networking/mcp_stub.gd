extends Node

"""
MCP stub: listens for JSON over TCP from external bot clients.

This is a simple, single-connection TCP server that parses newline-delimited
JSON messages and emits a signal for incoming events. It's intentionally minimal
— use it as an integration point for external bots (MCP clients).
"""

signal bot_message(parsed)

var server: TCPServer = null
var client: StreamPeerTCP = null

func start(port: int = 5000) -> bool:
    server = TCPServer.new()
    var err = server.listen(port)
    if err != OK:
        push_error("MCP: Failed to listen on port %d (err=%s)" % [port, str(err)])
        return false
    print("MCP: Listening on port %d" % port)
    set_process(true)
    return true

func stop() -> void:
    if client:
        client.close()
        client = null
    if server and server.is_listening():
        server.stop()
    set_process(false)

func _process(_delta: float) -> void:
    if server and server.is_listening() and not client:
        if server.is_connection_available():
            client = server.take_connection()
            print("MCP: Accepted client")
    if client and client.get_available_bytes() > 0:
        var raw = client.get_utf8_string(client.get_available_bytes())
        # Assume newline-separated JSON messages; parse each line
        for line in raw.split("\n"):
            if line.strip_edges() == "":
                continue
            var res = JSON.parse_string(line)
            if res.error != OK:
                push_warning("MCP: JSON parse error: %s" % [str(res.error)])
                continue
            emit_signal("bot_message", res.result)
