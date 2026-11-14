# Cosmic Detention — instructions for coding agents

## Project

This is a 48-hour game-jam project with five developers. Theme: **Cosmos**.
We are building a hilarious first-person LAN co-op game in **Godot 4.7.x / GDScript**.
Abducted human students must eat to survive an alien classroom while avoiding
a noise-sensitive, shotgun-wielding teacher. Multiplayer and physical comedy
are core, not optional polish.

- Godot project root: `cssa-game-jam/` (not the repository root).
- Entry scene: `cssa-game-jam/main/main.tscn`.
- Read `docs/DEVELOPMENT.md` for architecture, APIs, controls and team handoff.
- Read `docs/ASSETS.md` for prioritized human asset collection and integration.
- Prefer small, playable changes over speculative frameworks or scope expansion.

## Non-negotiable: scene-first Godot development

**Nodes belong in `.tscn` files, visible and editable in Godot's Scene dock.**

- Define meshes, colliders, cameras, markers, lights, controls, audio emitters,
  joints and their child hierarchies in scenes, not in `.gd` constructors.
- Scripts provide behaviour and reference existing nodes using `@onready`, `$`,
  `%UniqueName`, or exported node references.
- Runtime spawning is appropriate for dynamic entities, but instantiate a
  complete `PackedScene` prefab; do not build its hierarchy using `Node.new()`
  and a sequence of `add_child()` calls.
- Reusable furniture, characters, items and effects should have reusable scenes.
  Put layout, collider dimensions, materials, anchors and static signal
  connections in those scenes.
- Use authored `Marker3D` nodes for seats, loot, waypoints, chutes and dispensers.
  Do not duplicate their positions as hard-coded script coordinates.
- UI layouts belong in `.tscn` anchors/containers, not per-frame layout code.
- Ordinary non-node objects such as ENet peers, input events, query parameters
  and pathfinding data can still be created in scripts.
- Preserve node paths, unique names and scene connections used by scripts;
  update all references together when renaming or moving nodes.

## Settled game design — preserve unless explicitly changed

- **2–6 humans**, one player hosts with ENet; friends join an encoded IPv4 code
  on the same LAN. Normal UDP port: **7777**. No dedicated server or Steam.
- **No proximity voice chat or microphone capture.** This was explicitly cut.
- First person; **one held thing**, no inventory slots. Food, props, NPC clones
  and friends can be carried/thrown. Keep physical ragdolls and recovery.
- Single **Stomach / health** bar: time and damage deplete it, food refills it.
  Eating is loud; hunger, burps, impacts, footsteps and punches create noise.
- Configurable phases, currently **20s preparation / 120s class / 60s break**.
  Round, economy and spawn tuning lives in `config/game_config.tres`. That
  resource links the player, teacher and interaction settings. Audio paths
  and mixing live in `config/audio_config.tres`, and LAN ports and discovery
  timing live in `config/network_config.tres`. Item tuning stays with the
  item resources under `items/data/`.
- Teacher states include lecture, warning/check, investigation, coffee and
  caught/shoot, plus entrance/exit. Normal checks have a minimum cooldown and
  a readable warning before the slow turn. Investigations increase alertness.
- **Lecture is not immunity:** over-threshold noise can get a student caught
  while the teacher's back is turned. Checks are more sensitive; coffee is
  less sensitive, not deaf.
- Mixed blame: sound location draws suspicion; visible violations identify
  actors, otherwise proximity, behaviour and limited randomness can frame a
  nearby student. Do not make the teacher omniscient about unseen throwers.
- Dead players spectate until the class ends. If anyone survives, dead players
  re-clone at the bell for a Bitcoin fee. Debt is allowed; do not change this
  into permanent elimination. All humans dead simultaneously ends the run.
- Endless progression/score: classes survived and shared rocket parts.
  Rocket parts are not an individual competitive escape condition.
- Bitcoin allowances depend on food eaten; physical vending purchases drop
  into a tray. Grade progression unlocks items. NPC clones and weighted loot
  make the classroom feel alive. Gambling/roulette remains stretch scope.

## Architecture and editing locations

All paths below are relative to `cssa-game-jam/`.

| Area | Files |
|---|---|
| LAN lifecycle / codes | `autoload/net.gd` |
| Authoritative state, phases, economy, RPCs | `autoload/game.gd` |
| Gameplay noise / positional sound | `autoload/noise_bus.gd`, `autoload/sfx.gd` |
| Item lookup / resource schema | `autoload/item_db.gd`, `items/item_data.gd` |
| Classroom layout / integration behaviour | `world/classroom/classroom.tscn`, `world/classroom/classroom.gd` |
| Reusable desks and hallway props | `world/classroom/props/*.tscn` |
| Networked player | `characters/player/network_player.tscn`, `characters/player/network_player.gd` |
| Six-body physical ragdoll | `characters/player/ragdoll.tscn`, `characters/player/ragdoll.gd` |
| Shared character visual | `characters/shared/student_visual.tscn` |
| Teacher visual / AI | `characters/teacher/teacher.tscn`, `characters/teacher/teacher.gd` |
| Throwable behaviour / item prefabs | `items/throwable.{tscn,gd}`, `items/scenes/*.tscn` |
| NPC clone | `characters/npc/kid.tscn` |
| Item balance / rarity / grade / prefab references | `items/data/*.tres` |
| Menus / HUD / vending controls | `ui/game_ui.tscn`, `ui/game_ui.gd`, `ui/vending_entry.tscn` |
| Effect / audio prefabs | `effects/*.tscn` |
| Automated integration scenarios | `tests/` |

`world/classroom/classroom.gd` and `autoload/game.gd` are shared integration hotspots;
avoid unrelated edits there and coordinate with whoever is already modifying them.
The original player and test scenes live in `prototypes/`. Standalone snippets are in repository-level `reference/snippets/`.

## Multiplayer rules

- Host owns teacher/NPC decisions, item physics, ownership, health, money,
  purchases, seating and round transitions. Validate requests on the host.
- Owning peers simulate their own movement and physical player ragdolls;
  remote peers interpolate replicated poses. Do not enable input/cameras on
  every player or simulate loose item physics independently on clients.
- Existing RPCs live on `/root/Game`. Use stable peer/entity IDs rather than
  peer-local instance IDs or arbitrary node references in network payloads.
- Reliable channel 0: actions, events, registration and initial state.
- Unreliable ordered channel 1: compressed, chunked complete world snapshots.
  Keep chunks below the MTU and apply only complete matching sequences.
- Unreliable ordered channel 2: owner poses. Preserve epoch checks that reject
  stale poses after seating, teleporting, carrying, launching or respawning.
- `Game.request(action, data)` is the local action entry point.
- `NoiseBus.emit_noise(position, loudness, source_id, sound_key)` runs on the
  host. Gameplay loudness is independent of the audio mix. Teacher sounds
  bypass gameplay hearing so the teacher does not react to its own coffee.
- `Game.world.spawn_item(...)`, `Game.damage(...)`, and
  `Game.launch_player(...)` are host operations. See the development guide.
- Normal gameplay remains a trusted-LAN jam implementation. Do not add relay
  infrastructure, host migration or a new replication framework unrequested.

Collision bit values: **1 world, 2 players, 4 items, 8 teacher/NPCs,
16 interactables**. Do not confuse bit values with layer indices.

## Adding or replacing assets and items

- **Art and sound must not be AI-generated.** Use human-created assets or
  licensed sources supplied/approved by the team. Simple greybox geometry is
  fine; do not synthesize replacement audio or generate finished art.
- Missing audio is intentionally silent. Human recordings go under
  `assets/audio/<event>/<variation>.ogg` or `.wav`; Sfx discovers variations.
- Record creator, source URL, license and attribution in repository-level
  `used-assets.txt`. Preserve existing credits and import metadata.
- Prefer `.glb`, meters, Y up, characters facing -Z. Character origins at feet;
  item origins near center of mass. Keep visuals separate from colliders.
- Source models, Blockbench projects and original audio live in repository-level `art-source/`.
- Imported item models and their textures live in `assets/models/items/`.
- Replace item geometry inside `items/scenes/<item>.tscn`, not in code.
- New item: add an inherited throwable scene and an `items/data/*.tres`
  resource. Match `item_id`/`id`, assign its `scene`, and set price, grade,
  spawn weight and effect. Add a scene-authored vending entry with its
  `item_id` to expose its button; keypad ordering follows sorted stock.
- When furniture moves, keep its seat/loot/obstacle markers attached. Adjust
  `NavigationObstacle.half_extents` in the Inspector when its footprint changes.

## Verification

Run from the repository root:

```sh
godot --headless --path cssa-game-jam --editor --import --quit
python3 cssa-game-jam/tests/run_smoke.py
python3 cssa-game-jam/tests/run_network.py
git diff --check
```

- Smoke test: real host/client gameplay, authored scene nodes, contested
  pickup, throwing/carry/ragdoll recovery, vending, eating, teacher noise,
  cloning, progression, wipes and restart.
- Network test: six Godot processes, natural phase timers, late joining,
  shotgun/sightlines, replicated state and disconnect cleanup.
- `run_smoke.py --render` needs a display and also captures a rendered frame.
  Both runners choose a separate UDP port so they do not disrupt a live game.
- Run relevant tests after behavioural/scene changes; report what actually
  passed and any remaining failures. Do not claim automated tests prove fun,
  real multi-machine LAN compatibility or exported-build correctness.
- Manual two-machine LAN playtest and a full six-player demo rehearsal are
  still required, especially after physics, UI, layout or audio integration.

## Team safety

- Inspect current changes before editing. Other developers and agents may be
  working concurrently; do not overwrite, revert, clean or delete their work.
- Do not commit, push, reset or change branches unless requested.
- Do not add `.godot/` caches, temporary logs, screenshots or generated builds
  to version control. Keep Godot `.gd.uid` and appropriate asset `.import`
  metadata with their sources.
- Keep changes scoped to the request, use existing naming/style, and update
  relevant docs when scene paths or integration contracts change.
- Summarize changed files, verification and any handoff/blockers concisely.
