# Menu A independent audit — 2026-10-11

The current default-entry capture matches the approved TOP A direction: a deep-blue Gothic observatory and city skyline, silver title at upper left, five star-marked actions down the left, and the closed-eye prayer portrait filling the right half. The captured portrait keeps its head and clasped hands visible; its long hair and coat reach the lower edge. The action column remains legible, and the unavailable Continue action is visibly muted.

The menu remains interactive. The existing route is `scenes/main.tscn` -> `scripts/ui/main.gd::_ready()` -> `show_start_menu()` -> `StartMenu`; the five keys remain ordered `new`, `continue`, `authority`, `journal`, `quit`. Their dispatch remains connected to new exploration, continue/resume, authority collection, journal, and quit. Continue is disabled without an active saved or suspended exploration. Current code shows the existing exploration resume path and the five dispatch cases; the final GPU log additionally records journal/collection returns, new exploration, same-session continue, and persisted-map continue.

The new motion stays subtle and preserves the composition: `menu_a_sky.gd` brightens fixed star points in place; `menu_a_button.gd` animates hover/focus highlights and press feedback; `start_menu.gd` fades the canvas in. The final GPU log records 56 checks with zero failures, including mouse and keyboard feedback, fixed portrait geometry, small-window layout, five actions, hit-target checks, eight mouse clicks, and the configured default scene. The separate quit acceptance was reported by the lead as passing against the actual executable.

Both selected reference assets are RGBA with alpha extrema 0..255: `menu_a_reference_portrait.png` (1448x1086) and `menu_a_reference_title.png` (2094x751). The screenshot itself is 1440x900. The menu chooses a system serif when available (`SimSun`, `Songti SC`, `Source Han Serif SC`, `Noto Serif CJK SC`) and falls back to bundled `assets/msyh.ttc`; the final screenshot shows Chinese text rendered. The gameplay pixel assets, proximity E interaction, and three authority cards are outside the menu implementation and were not exercised by this visual audit.

## Existing acceptance failure

The unchanged `tests/start_menu_acceptance.gd` log reports exactly two failures: “Existing battle route still opens” and “Battle UI instances restore intact.” The failing sequence is lines 63–77: it creates a unique fresh save, starts the legacy `begin_expedition(true)` route, requests the legacy boss encounter, and calls `confirm_loadout()` without equipping a card. `main.gd::_ready()` initializes that fresh save through `store.initialize_time_authority(save_path)`. This initializer sets missing legacy `collection` and `equipped_ids` fields to empty arrays; it does not grant legacy starter cards. `confirm_loadout()` passes `store.get_loadout()` to `Combat.start_battle()`, and the combat method rejects an empty accepted loadout. Therefore `confirm_loadout()` leaves the screen in `equip`, which accounts for both assertions expecting `battle`. This is a pre-existing legacy-route assumption in the acceptance script, not a changed menu route. No tests or gameplay code were changed to conceal or work around it.

## Test-tree hash audit

The frozen baseline contains 111 files. All 111 original paths still have matching SHA256 and byte size. Integration added nine files under `tests/**`: `menu_a_quit_acceptance.gd`, `menu_a_reference_render.gd`, their `.uid` files, and five generated `.uid` files for existing scripts. No pre-existing test file content changed. The complete after-state hashes are in `docs/verification/menu_a_tests_after_2026-10-11.json`.

## Evidence and limits

- Screenshot reviewed: `docs/verification/menu_a_default.png` (1440x900).
- Final GPU acceptance log: `docs/verification/menu_a_reference_final_stdout.log` (`checks=56 failures=0 mouse_clicks=8 default_scene=res://scenes/main.tscn`).
- Existing acceptance output: `docs/verification/menu_a_existing_acceptance_stdout.log` and `docs/verification/menu_a_existing_acceptance_stderr.log`.
- I did not execute Godot during this audit. The execution evidence above is the recorded output supplied by the integration run.
- This checkout has no Git metadata, so the audit verifies the requested `tests/**` baseline by hashes and confirms routing by current source inspection; it cannot independently produce a source diff.
