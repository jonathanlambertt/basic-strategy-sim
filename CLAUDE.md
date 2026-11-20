# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A blackjack basic-strategy trainer built in Godot 4.7 (GDScript, GL Compatibility renderer). The player plays hands, and every decision is graded against the basic strategy chart for the current table rules.

## Commands

Godot is not on PATH. NOTES.md uses `Godot_v4.7-stable_win64_console.exe`, so substitute the local path to that binary for `godot` below.

```sh
# Unit tests (headless). Exit code 1 on any failure; prints "ALL N CHECKS PASSED" on success.
godot --headless --path . --script res://tests/run_tests.gd

# Long house-edge simulation (see NOTES.md for the method and the last results)
godot --headless --path . --script res://tests/sim.gd -- <seed> <rounds> <h17 0|1>

# Drive the real game and save PNG screenshots (needs a window, so don't pass --headless)
godot --path . --script res://tests/shots.gd -- <output dir>

# Run the game
godot --path .
```

- You can't select a single test. The tests are the `test_*` functions called from `_init()` in `tests/run_tests.gd`, so comment out the calls you don't need. `test_simulation` plays 2 × 200k rounds, so the full suite isn't instant.
- All three test scripts `extends SceneTree` and rely on the `class_name` globals. A new `class_name` script isn't visible to `--script` runs until Godot rescans the project (open the editor, or run `godot --headless --path . --import`).

## Architecture

### Core logic and view are separate

`scripts/core/` is pure logic (`RefCounted`, no nodes) and can be tested headlessly:
- `BlackjackEngine` (engine.gd) holds the round state machine (`Phase`: BETTING → INSURANCE → PLAYER → ROUND_OVER), the bankroll and the payouts.
- `Hand`, `Shoe`, `Rules` and `Stats` are its data types.
- `Strategy` is the basic-strategy chart plus the rule-of-thumb text.

`scripts/game.gd` is attached to the only scene (`scenes/main.tscn`). It builds every node in code and only renders the engine's results.

### Event protocol

The engine's public mutators (`start_round`, `insurance`, `act`) apply the whole state change at once and return an `Array[Dictionary]` of events. Each event has a type key `"t"`, and the event types are documented at the top of engine.gd. `game.gd::_play` awaits `_apply(e)` for each event in turn so that it can animate them.

The view keeps its own copy of what has been shown so far (`view_hands`, `dealer_sprites`, `ui_phase`, `display_bank`). This copy lags behind the engine until the animation finishes, and the `busy` flag blocks input until then. When you add engine behaviour the player should see, emit a new event and handle it in `_apply`.

Invalid engine calls don't throw. They call `push_error` and return an empty event list. A headless loop that ignores that result can spin forever: this happened in sim.gd when it bet below `MIN_BET` ($5).

### Cards and rigged shoes

- A card is an int from 0 to 51: `rank = id % 13 + 1` (1 = ace, 11–13 = J/Q/K) and `suit = id / 13`.
- Cards appended to `Shoe.rigged` are drawn next, in order. Both the tests and `shots.gd` use this to script hands.
- The deal order is player, dealer up card, player, dealer hole card. After that, cards come out in the order the player acts.

### Strategy and grading

- `Strategy.chart(rules)` builds the chart from the `hard_cell`, `soft_cell` and `pair_cell` functions and caches it by `Rules.chart_key()`. Deck count is not part of the key, because 4, 6 and 8 decks share one chart.
- Cells hold codes (`H S D DS P RH RS RP`). `resolve()` turns a code into an action based on what's currently allowed.
- `engine.act()` calls `best_play()` before it applies the player's action. It records the result in `Stats` and emits a `decision` event, so every action is graded.
- `tests/run_tests.gd` checks the chart against tables typed in from the published 4–8 deck chart, for every rules combination. If you change a cell, update those expected tables too.
- The plain-language explanations (`_hard_rule`, `_soft_rule`, `_pair_rule`, `guide()`) are written by hand and no test checks them against the chart. Update them by hand whenever a cell changes.

### Rules

`Rules` has four adjustable fields: `decks`, `h17`, `das` and `surrender`. Everything else is a constant (3:2 blackjack, at most 4 hands, 75% penetration). Rules can only change between rounds, through `engine.set_rules()`, and changing the deck count shuffles a new shoe. Both the engine and the settings overlay keep their own `copy()` of the rules.

### Rendering and UI

- There are no image or font assets. `Art` holds the palette and generates the card and chip textures in code. `PixelFont` is a 5×7 bitmap font that only has uppercase glyphs. Text is uppercased before drawing, and any character missing from `GLYPHS` is drawn as `?`.
- The UI draws itself with custom `_draw` code (`PixelButton`, `ChipButton`, the HUD in `game.gd::_draw_hud`), not with Godot Control themes.
- The viewport is 640×360 with integer scaling and nearest-neighbour filtering. Positions are rounded to whole pixels, and new drawing code should round them too.
- Full-screen panels (chart, stats, table rules) subclass `Overlay`. They override `_draw_content()` and `handle_key()`, and `game.gd::_open_overlay(kind)` opens them. Overlays sit on CanvasLayer 5 and the CRT shader pass on layer 10.
- `game.gd::_unhandled_input` handles every keyboard shortcut. `_press(button)` only fires a button that is visible and enabled.
- `tests/shots.gd` calls private methods directly: `_on_deal`, `_on_action`, `_on_insurance`, `_open_overlay`, `_close_overlay`, `overlay.set_tab`, `overlay._scroll_by` and `overlay._choose`. Renaming any of them breaks the screenshot script.

## Conventions

- GDScript is statically typed throughout (`:=`, typed arrays, typed signatures) and indented with tabs. Files use LF line endings (`.gitattributes`).
- All text shown to the player is written in uppercase string literals.
- NOTES.md records the house-edge simulation results and how to run them. Update it when you rerun the simulation or change payouts.
