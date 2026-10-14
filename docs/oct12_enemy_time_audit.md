# Oct 12 enemy and local-time integration audit

Scope: read-only review of the Oct 12 exploration enemy AI, temporal target integration, hit signal, HP update, checkpoint/retry flow, and target picking. No source edits or Godot runs were performed.

## Findings

No concrete source defect requiring a fix was found in the requested paths.

- Enemy motion uses a per-enemy `EnemyBrain` in spatial combat, while exploration previews use a per-enemy local state and advance only through the temporal controller. Windup, strike, and recovery feed the actor motion state; target selection gives enemy hit rectangles precedence when they overlap the player or broad scenery targets.
- The authority preview attack emits one serial-keyed `enemy_attack_hit` only after its windup, and returns immediately when the hit opens a lethal modal. The session ignores invalid, duplicate, non-authority, suspended, or non-exploration hits, clamps HP at zero, and updates the HUD from `run.hp`.
- Stop skips local advancement and capture, reverse restores captured object state, and pause exits the temporal advance before target callbacks. The new acceptance test covers stopped position/rig/attack/HP, single-hit resolution, reverse, miss conditions, lethal defeat, and retry reset.
- Safe checkpoint saving is blocked while an enemy has hostile attention or HP has reached zero. Retry restores the stored safe checkpoint, resets enemy state/serials and temporal history, and resumes exploration. This keeps active danger from becoming the retry point.
- Map enemy spawn heights inspected in `chapter_map.gd` lie on authored flat surfaces: tutorial/stairs/corridor/boss on ground, patrol on the middle lamp platform, and lamp/elite on ground. The AI surface and bounds selection therefore have a supported surface for the current authored encounters.

The time renderer mentioned in task context is not wired into the reviewed world path; this audit did not modify or validate that separate presentation work. Since it is known to be unwired, it should not be treated as verified runtime feedback.

## Test inventory

`docs/verification/oct12_tests_before.json` recorded 120 files. The after inventory has 121 files: all 120 baseline hashes are unchanged, no baseline file is missing, and the sole new file is `tests/oct12_enemy_time_delta.gd`. The parent reports one valid 15-check run of that new test; I did not independently run it. The earlier harness parse-error attempt occurred before any test case executed. No pre-existing suite was run as part of this audit.

Hash details are in `docs/verification/oct12_tests_after.json`.
