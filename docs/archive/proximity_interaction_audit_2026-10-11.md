# Proximity interaction final audit — 2026-10-11

## Result

The requested contextual interaction flow passes the available session, world, and GPU evidence. No runtime defect was found. Existing runtime code and existing tests were not modified during this audit.

## Behavior checked

- `available_interaction_id()` restricts prompts to nearby, eligible registered targets; `interact()` performs a fresh proximity check at keypress, so a stale prompt cannot trigger a distant object.
- The map draws a contextual E badge only for a valid nearby interaction. Paused state, active encounters, and unmet device tutorial gates suppress interaction; modal entry also hides the prompt.
- Pressing E emits the world interaction signal and routes to the matching Godot UI. Device, NPC, supplies, rest, bridge observations, and other registered entries are covered by the session acceptance flow.
- Opening the repair UI grants no cards. The repair action grants exactly three named time cards: 停止时间, 快进时间, 倒退时间. Reopening the repaired device does not offer a second repair.
- Dialog entry clears movement and hides tutorial hints. Escape or Continue resumes exploration, clears movement again, and restores the hint only while onboarding remains incomplete.
- Production onboarding hint strings contain only contextual narrative / location text; no persistent map or tutorial key instructions remain.

## Recorded validation

- `proximity_interaction_session_stdout.log`: 22 checks, 0 failures.
- `proximity_world_regression_stdout.log`: 26 checks, 0 failures.
- `proximity_interaction_gpu_stdout.log`: 31 checks, 0 failures; five 1440×900 screenshots cover far range, valid prompt, device dialog, repaired continuation, and NPC dialog.
- `authority_session_after_dialog_stdout.log`: 24 checks, 0 failures.
- GPU evidence uses placed fixtures settled through simulation, not a complete playthrough across the entire map.

The old `proximity_onboarding_unchanged` run reports one failure at `tests/onboarding_acceptance.gd:83`: it expects the removed literal hint `E  调查灯台`. This is an obsolete test expectation; the test file remains unchanged. The previous GPU flow that expected an immediate grant on E is also superseded by the explicit repair-button flow and was not rerun as a current acceptance test.

## Test-file integrity

All 109 files recorded in `proximity_tests_before_2026-10-10.json` retain their original SHA-256 hashes and byte counts. Two new test files are present relative to that baseline: `tests/proximity_interaction_render.gd` and `tests/proximity_interaction_session_acceptance.gd`. Their hashes and the recorded log hashes are listed in `proximity_tests_after_2026-10-11.json`.

No issue was found that calls for expanding the requested interaction scope.
