# Doppelkopf (Godot 4) — project scaffold

Doppelkopf is a traditional german card game for four players.

# Disclaimer

This project is an experimental AI project for generating a Doppelkopf game with Godot4. This is not production‑ready and is only updated when I have spare compute tokens. You’re welcome to use, modify, or extend it in accordance with the project’s license. 


# How to

Quick start:

1. Open project in Godot 4.
2. Run `scenes/main.tscn` as main scene.

Notes:
- Language: GDScript.
- Default ruleset: `rules/default_rules.json` (editable in-game later).
- Networking: `networking/mcp_protocol.md` contains MCP stub for external bots.

Next steps:
- Implement full `GameModel` logic, rules engine, scoring.
- Build AI heuristics and tests.
- Add animated UI and assets.

# TODOs

- add godot action workflow for tests
- Stronger/Configurable AI
- multi language support
- network multiplayer
- stronger graphics
- improve readme
- ...
