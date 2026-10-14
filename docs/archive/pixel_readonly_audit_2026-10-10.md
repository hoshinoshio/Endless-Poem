# Pixel roster read-only audit — 2026-10-10

Scope: read-only check of the pixel roster state, active scene wiring, image sources and crop geometry, review notes, and the frozen test hash inventory. No existing project, test, asset, or baseline file was changed, and no tests were run.

## Status

This section and its initial findings record the pre-correction snapshot. See the final recheck below and `pixel_full_acceptance_2026-10-10.md` for the current integrated result.

- `project.godot` launches `scenes/main.tscn`; `main.tscn` runs `scripts/ui/main.gd`. Its `_ready()` displays the start menu, and the new expedition action opens the exploration session/world.
- The exploration player calls `PixelActor.configure_key("player")`; the exploration world calls `configure_key("musheng")` for 暮笙. Combat actors resolve their configured `pixel_key` through the same manifest. `configure_key()` requires `ready=true`, which is now true, and the 48×64 manifest format; there is no default-world preview-only check gating these calls. The preview scene still exists as a separate tool.
- Manifest `assets/pixel_v1/manifest.json`: `ready=true`, `status=approved_pixel_style_active_full_roster`, frame size 48×64, and `approved_motion` records user acceptance of the size and gait. The player has 48 source frames; guard, elite, boss, instrument, observer, anchor, and musheng each have 20.
- The eight keys map to ten existing source PNGs: Moonli uses the locomotion, action, and combat sheets; each other key uses its matching `*_raw.png`. All PNG sheets have alpha. Every manifest rectangle is within its source sheet. Non-player actor output silhouettes fit their 48×64 canvas.
- 暮笙 is configured as an exploration NPC at `exploration_world.gd` and has its own `musheng` manifest key and `talk` animation. `chapter1_assets.gd` also retains `enemies.musheng` as a compatibility alias, but that alias does not change the world actor's NPC role.

## Findings requiring follow-up

1. **Moonli's rendered frame clips at the bottom edge.** Replaying `pixel_actor.gd`'s nearest-neighbor resize and anchor placement against the authored images found nontransparent output pixels beyond canvas row 63 in frames 25, 26, 28, 36, 37, 38, 39, and 43 (zero-based). All clipping is at y=64; 140 opaque pixels total are lost across those frames. Other seven roster keys have no clipped alpha pixels. The manifest crops themselves are in-bounds; this is output-canvas clipping after scaling/placement.
2. **Review documentation is stale.** `docs/pixel_full_roster_acceptance_2026-10-09.md` still says the manifest is `ready=false`, player-only, and awaiting visual review. `assets/pixel_v1/GENERATION.md` likewise says pending user review and preview-only. These statements conflict with the active manifest's approved full-roster state and runtime wiring. The manifest's `approved_motion` field is current.
3. **A pilot test fixture is obsolete at the expanded frame count.** `tests/pixel_authored_assets.gd` asserts `rig.textures.size()==32` and 32 distinct frames. The manifest now supplies 48 player frames, so those fixture assertions will fail for the intended expanded roster. Per audit scope this test was not edited or run.

## Frozen test inventory

`docs/verification/pixel_motion_tests_before_2026-10-09.json` contains 91 file/hash entries. All 91 files are present and match the recorded SHA-256 values. Current `tests/` has 53 `.gd` scripts and `.gd.uid` files; 15 entries are outside the frozen 91-entry inventory. Of those, the six additional test scripts are `pixel_authored_assets.gd`, `pixel_monster_states.gd`, `pixel_motion_continuity.gd`, `pixel_motion_preview_render.gd`, `pixel_spatial_feedback.gd`, and `pixel_world_integration.gd`. The other nine outside-inventory entries are generated `.uid` files (`authority_motion_render`, `authority_playthrough_render`, plus pixel actor/authored assets/monster states/motion continuity/motion preview render/spatial feedback/world integration). None were modified by this audit. The full frozen inventory hash match also confirms any earlier subset among those entries remains unchanged; there is no Git metadata in this project directory to independently identify a separate 37-file subset.

## Audit boundary

This was static source/manifest/image inspection plus hash comparison. It does not assert a fresh Godot runtime launch or rerun of the tests. The evidence paths are `project.godot`, `scenes/main.tscn`, `scripts/ui/main.gd`, `scripts/exploration/exploration_player.gd`, `scripts/exploration/exploration_world.gd`, `scripts/world/combat_actor.gd`, `scripts/visuals/pixel_actor.gd`, `scripts/visuals/chapter1_assets.gd`, `assets/pixel_v1/manifest.json`, `assets/pixel_v1/roster_frames.json`, `assets/pixel_v1/GENERATION.md`, `docs/pixel_full_roster_acceptance_2026-10-09.md`, `docs/verification/pixel_motion_tests_before_2026-10-09.json`, and `tests/pixel_authored_assets.gd`.


## Final recheck — 2026-10-10

- Recomputed all 188 manifest frames from their source PNG rectangles using `pixel_actor.gd` sizing and destination-anchor rules. The earlier 140-pixel bottom clipping is resolved: **0 alpha pixels are clipped**, all 188 output frames retain their resized nontransparent pixels on the 48×64 canvas, and all source crop rectangles remain in bounds. All referenced source PNGs contain alpha. The raster check is static; it does not replace a Godot render.
- Frozen test integrity: `tests_frozen_2026-10-09.json` is **37/37 matching**; `pixel_motion_tests_before_2026-10-09.json` is **91/91 matching**.
- Inspected `pixel_pilot_contract_final_unchanged_stdout.log`: it contains the expected two obsolete 32-frame assertions (`32 supplied source frames present` and `all32 authored raster frames are distinct`); the remaining nine checks pass. No tests were run and no test files were changed.
- The documented anchor correction is present in `assets/pixel_v1/manifest.json` and `tools/merge_pixel_roster.py`. This audit added `docs/verification/pixel_final_asset_audit_2026-10-10.json` and this dated note only.

Integration note: the main agent subsequently refreshed README and GENERATION.md and marked the two 2026-10-09 pixel reports as historical snapshots. This resolves the stale-document finding; it does not alter the original audit or the two intentionally preserved pilot assertion failures.
