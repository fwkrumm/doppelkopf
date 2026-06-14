# agents.md — Doppelkopf (Godot 4) constraints

## Overview
Project: Doppelkopf card game for Godot 4. Single-player + multiplayer. Rules fully configurable.

## Platform & Engine
- Target: Windows (primary export).
- Engine: Godot 4.6.2 stable. Language: **GDScript**.
- Exe: `C:\Users\notav\.local\bin\Godot_v4.6.2-stable_win64_console.exe`
- Project: `C:\Users\notav\dev\doko`

## Deck & Rules
- Deck: configurable; default = 40-card. Optional 48-card.
- Rules configurable minimum:
  - Re/Kontra, Solo, Hochzeit, Rufspiel
  - Pflicht/Schweinchen variants
  - Sonderpunkte, Augenwertung
  - Bock rounds and triggers
- Scoring: fully configurable (granularity, rounding, thresholds).
- Extensible for future variants.

## Players & Bots
- 4 fixed seats; bots auto-fill empty seats.
- External bots: connect via MCP server (JSON over TCP/WebSocket). Host assigns seat.

## Multiplayer & Networking
- Host-client authoritative (ENet via Godot high-level multiplayer).
- Host validates moves, broadcasts game state.
- MCP API: handshake, seat assignment, game events, action requests.

## AI
- Current: rule-based heuristic agent (`scripts/ai/heuristic_agent.gd`). Follows effective suit, discards lowest-point card otherwise.
- Future: MCTS / learning via plugin or external-bot interface.

## UI Architecture (3D table)
- `SubViewportContainer` (MOUSE_FILTER_STOP, size driven by signal) → `SubViewport` (own_world_3d, physics_object_picking=true, MSAA_4X, FXAA) → 3D scene + Camera3D.
- `CanvasLayer` (layer=10) lives **inside** the SubViewport — not the main viewport. Required for 2D buttons and 3D Area3D picking to coexist.
- `scripts/ui/game_3d.gd`: 3D table, card meshes, trick/hand layout, bot labels, inspect animation.
- `scripts/ui/card_3d.gd`: individual card node. `clicked(card_node)` signal via Area3D. `set_interactive(bool)` toggles ray picking.
- Seating clockwise: P0 = south (z+), P1 = west (x−), P2 = north (z−), P3 = east (x+).
- Camera: `look_at_from_position(Vector3(0,6,4.5), Vector3(0,0,0.3), UP)`, fov=52.

## Persistence
- Local match saves, player profiles, replays (event stream), leaderboards.
- Storage: JSON in `user://`. Optional server sync later.

## Tests
- Unit tests: game model, rules, scoring.
- Integration: AI decisions, game flow.
- Network simulation: host-client + external-bot stubs.
- Framework: GUT or Godot built-in runner.

## Config & Extensibility
- Rulesets: JSON files. In-game editor UI (`scenes/rules_config.tscn`).
- Core modules: GameModel (rules, state, scoring), Controller (turns, validation), UI, Networking.

## Exports
- Windows only (initial delivery).

---

## Godot 4 API Notes (verified)

### Compatibility (Godot 3 → 4)
- `Reference` → `RefCounted` in `deck.gd`, `player.gd`, `scoring.gd`, `ai/heuristic_agent.gd`.
- Signal connect: `signal.connect(Callable(self, "method"))` — old 3-arg form broken.
- Array: `is_empty()` not `empty()`. `remove_at()` returns void — capture item before calling.
- No `to_string()` override on Object → renamed to `as_text()` in `card.gd`.
- `DirAccess`: instance via `DirAccess.open("user://")`, then call instance methods.
- JSON: `JSON.parse_string(text)` returns the parsed object directly. For persistence prefer `FileAccess.store_var()` / `get_var()`.
- Type inference: `var x := some_func()` fails if return type undeclared → use `var x =`.

### Input routing (3D picking + 2D GUI together)
- `SubViewportContainer.mouse_filter = MOUSE_FILTER_STOP` — required to forward mouse into SubViewport.
- `SubViewport.physics_object_picking = true` — required for `Area3D.input_event` / `mouse_entered` / `mouse_exited`.
- `CanvasLayer` must be child of SubViewport, not the main viewport — otherwise it blocks `_gui_input` forwarding.
- `VBoxContainer.mouse_filter = MOUSE_FILTER_IGNORE` — PASS routes only to parent, skips sibling buttons.
- `HBoxContainer.mouse_filter = MOUSE_FILTER_IGNORE` — default STOP would block children.

### Window resize with Node parent
`PRESET_FULL_RECT` on a Control whose parent is a plain `Node` does not propagate resize events. `get_viewport().size` can also cap at the project's configured viewport size (1152×648 default) when the window grows — use `get_window()` instead. Correct pattern (no preset):
```gdscript
get_window().size_changed.connect(func(): svc.size = Vector2(get_window().size))
svc.set_deferred(&"size", Vector2(get_window().size))
```
Even more robust: use `_notification(NOTIFICATION_WM_SIZE_CHANGED)` which is broadcast to ALL nodes, and set both the container size AND the SubViewport size explicitly. Promote `svc`/`svp` to instance vars for access outside `_ready`. Also call `get_window().max_size = Vector2i(0, 0)` in `_ready` to prevent any implicit cap.

**Root cause / correct fix**: `Node` does not participate in the Control resize chain. When the Window resizes it sends `NOTIFICATION_RESIZED` only to direct **Control** children. Make the main scene root a `Control` (not `Node`) and use `PRESET_FULL_RECT` on both the root and the `SubViewportContainer` — the anchor chain propagates every resize automatically with no manual wiring:
```gdscript
# main.tscn root: type="Control"
# main.gd
extends Control
func _ready():
    set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    mouse_filter = MOUSE_FILTER_IGNORE
    var svc := SubViewportContainer.new()
    svc.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    svc.stretch = true
    # ...
```

### Anti-aliasing
```gdscript
svp.msaa_3d = Viewport.MSAA_4X
svp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
```

### Team assignment
- `assign_teams()` called after `deal()` every round.
- Counts Queen of Clubs (`suit == "CLUBS" and rank == 12`) per player.
- Normal (2 holders, one each): Re = team 1, others = Kontra = team 0.
- Stille Hochzeit (1 holder has both): holder = Re, others start as Kontra. First trick won by a non-holder → that player joins Re. State tracked via `_hochzeit_active` / `_hochzeit_holder_id` in `GameModel`.
- Fallback (custom deck, no queens found): alternating `i % 2`.

---

## Console Commands

```powershell
# Parse-check a single script
& 'C:\Users\notav\.local\bin\Godot_v4.6.2-stable_win64_console.exe' --path C:\Users\notav\dev\doko --check-only --script res://scripts/game_model.gd

# Headless smoke test (quit after 5 s)
& 'C:\Users\notav\.local\bin\Godot_v4.6.2-stable_win64_console.exe' --path C:\Users\notav\dev\doko --display-driver headless --audio-driver Dummy --quit-after 5

# Run a probe/tool script
& 'C:\Users\notav\.local\bin\Godot_v4.6.2-stable_win64_console.exe' --path C:\Users\notav\dev\doko -s res://tools/json_probe.gd --display-driver headless --audio-driver Dummy
```

Parse errors → file + line number in output. Fix API mismatch in that script first.

---

## Next Steps
- Hochzeit declaration flow (announce before play starts; partner reveal on first trick win already implemented).
- Re/Kontra announcement UI.
- Solo game type detection + team override.
- Networking: ENet host-client stub + MCP external-bot protocol.
- Expanded AI heuristics (team-aware play, trump management).
- Animated dealing sequence.
- Comprehensive unit + integration tests.

