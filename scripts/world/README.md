# CombatStage visual adapter

`res://scenes/world/combat_stage.tscn` instantiates a real `Node2D` stage with
`Camera2D`, `Sprite2D` background/foreground layers, and per-entity actors containing
`Sprite2D`, `AnimatedSprite2D`, `Area2D`, and `CollisionShape2D`.

Public API:

```gdscript
stage.configure(encounter: String, assets: Dictionary)
stage.sync_snapshot(snapshot: Dictionary)
stage.consume_events(events: Array)
stage.advance(real_delta: float, battle_delta: float)
stage.get_target_rect(id: String) -> Rect2
stage.target_selected.connect(callback) # callback(id: String)
```

`actors` maps the authoritative snapshot entity ID to its actor. The protagonist
always uses `player`. Enemy IDs, including spawned anchors, come directly from
`snapshot.enemies`. Actor snapshots are presentation copies; this adapter never
edits the combat model, combat values, progression, or saves.

Advance by the actual difference in model `time` before and after its tick.
Do not approximate that difference with `real_delta * time_scale`, because the
combat model can cross a slowdown boundary inside one tick. Pass zero combat
delta during pause. Sprite frame playback, feedback, and retirement all use this
combat delta. `real_elapsed` is available separately and has no animation effect.

Manifest example (paths are illustrative slots, not provided or approved art):

```gdscript
{
    "player": {
        "texture": "res://assets/moonli_battle_v1.png",
        "sprite_frames": approved_moonli_frames,
        "height": 310,
        "position": [270, 552]
    },
    "enemies": {
        "guard": {"texture": approved_guard_texture, "sprite_frames": approved_guard_frames},
        "boss": {"texture": approved_boss_texture, "sprite_frames": approved_boss_frames},
        "anchor": {"texture": approved_anchor_texture}
    },
    "encounters": {
        "boss": {
            "layers": [
                {"id":"background", "texture": approved_background, "z_index":-20},
                {"id":"foreground", "texture": approved_foreground, "z_index":20,
                 "position":[720, 520], "size":[1440, 96]}
            ],
            "enemies": {"boss":"boss", "anchor":"anchor"}
        }
    }
}
```

Texture and SpriteFrames slots accept loaded resources or `res://` paths.
Vectors accept `Vector2` or two-element arrays. SpriteFrames support named
`idle`, `cast`, `hurt`, and `defeat` animations, configured frame durations/FPS,
and looping. An optional `attack` animation can depict enemy actions; without it,
the adapter plays `cast`. `attack`, `cast`, `hurt`, and `defeat` should be nonloop animations; idle
usually loops. Idle must exist when supplying frames without a static texture.
All frames should share a consistent anchor and canvas for stable visual placement.
The stage manually advances the actual frame index; it does not move a static
image and claim that movement is frame animation.

Enemy asset lookup priority is `enemies[id]`, encounter `enemies[id]` / `enemies[kind]`
mapping to the shared catalog, then the shared catalog's `kind` entry. A top-level
entity-ID asset entry is also accepted. Shared top-level `layers` are used when
the encounter has no layer override. Layers default to fitting the battle field
`Rect2(0, 80, 1440, 488)`, centered at `(720, 324)`. Explicit `size` or `scale`
can be used for transparent foreground strips. Compose front layers so they do
not obscure actors or their UI. Transparent pixels remain transparent.

Actor sprites are anchored at their feet near y=552. Player defaults to x=270;
Boss stays at x=1030. Other actors receive a stable slot on their first appearance
between x=740 and x=1240; their fitted position and size are retained for that ID.
Anchors receive separate left/right slots at x=750 and x=1270, with width capped
at 120 and height 145. Summoning or destroying anchors does not move or rescale
existing actors. Explicit manifest positions still override these defaults.
Actor bounds fit the assigned slot width and height. `get_target_rect` returns world coordinates matching the
1440x900 viewport when the stage has an identity transform; the stage camera is
centered at `(720, 450)`. Keep the stage at an identity transform and use a
CanvasLayer for HUD controls. Controls over the battlefield must ignore mouse
events unless they intentionally handle them. Target Area2D bounds cover the
fitted sprite canvas; transparent pixels are included in these rectangular bounds.

`missing_assets` records encountered missing resources as strings:

- `scene:<encounter>`: no configured scene layers.
- `layer:<id>`: configured layer has no loadable texture.
- `actor:<entity ID>:<kind>`: no enemy/actor art; the entity exists as an invisible
  Node2D with no input target. No replacement geometry, text monster, or image is created.
- `animation:<entity ID>:<missing states>`: actual animation resources are missing;
  the approved static seed or available idle frames are used as explicit fallback.

The only default production image is the approved Moonli v1 PNG. A missing enemy
slot never defaults to Moonli or to test fixtures. Missing animation diagnostics
do not imply that static art is missing. The collection is an attempted-resource
record reset by `configure`; it does not preflight future entities. The integration
must preflight future anchor kinds for boss/support encounters if required.

Events use the existing combat-model schema. `cast` animates player, `hit` animates
the event's target, `death` animates the defeated actor, `loss` animates player,
and `phase` animates the known boss actor. All events are forwarded through
`presentation_event`. Enemy attack actors cannot be inferred from a `hit` event
without an attacker field. Instead, increasing enemy `action_index` in successive
snapshots plays that actor's optional `attack` frames or `cast` fallback. The initial
snapshot only seeds the index and never fabricates an attack. Removed entities become noninteractive immediately;
their defeat view is retained for 0.65 combat seconds before removal.

Verification: `tools/run_godot.ps1 -Script res://tests/world_acceptance.gd
-LogName world_acceptance`. Test textures are generated entirely in the test
script, never saved to the game asset directory, and never used as production art.
