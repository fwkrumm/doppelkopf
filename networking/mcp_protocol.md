# MCP protocol (external bot integration) — stub

Overview:
- JSON over TCP or WebSocket (UTF-8, newline-delimited frames).
- Host authoritative. External bot connects, authenticates, receives seat assignment.

Handshake example:
```
{ "type": "hello", "version": "1.0", "name": "bot-name" }
{ "type": "welcome", "seat": 2 }
```

Key messages:
- `state_update`: server → bot, full/partial game state snapshot
- `action_request`: server → bot, asks for next action (request_id, allowed_actions)
- `action_response`: bot → server, chosen action for request_id
- `event`: server → bot, informational (trick taken, round end, score updates)

Notes:
- Keep payloads compact. Use numeric IDs for cards where possible.
- Full schema to define later. This file is a starting point for MCP support.
