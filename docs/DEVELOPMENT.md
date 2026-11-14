# Cosmic Detention — five-developer handoff

## Run

Open `cssa-game-jam/project.godot` in **Godot 4.7.x** and press F6 on `main/main.tscn` or F5 for the project. One player selects **Host Classroom**. Up to five others select **Find LAN Games**, choose the host, and select **Join LAN Game**, or enter the host's Wi-Fi IP or join code. Host presses **Enter** after skipping the intro to start. `127.0.0.1` works for two local instances.

Host codes encode IPv4 only. Normal play uses UDP **7777** for gameplay and UDP **7778** for LAN discovery. Discovery uses the source address of the host's reply. Test runners pass a separate `--port=` to both peers so they can run alongside a live game. If the automatic interface choice picks a VPN/virtual interface, enter the host's LAN IPv4 in the host address field. No dedicated service, Steam, relay, account, or voice dependency.

## Controls

| Input | Action |
|---|---|
| WASD / mouse | Move / look |
| Shift / Space | Sprint / jump |
| E | Grab, sit, coffee, vending |
| LMB with empty hand | Punch |
| Hold/release LMB with object/friend | Charge and throw |
| RMB | Eat / use held object |
| Q | Drop |
| Space while seated | Stand |
| Space while carried | Struggle; three presses frees you |
| F | Fart |
| Tab / F3 | Class register / debug info |
| Esc | Menu (multiplayer keeps running) |
| Enter in lobby/game over | Host starts a new run |
| Space / Ctrl when dead | Fly up/down while spectating |

## Implemented loop and decisions

- Host-authoritative teacher, object physics, NPCs, economy, health, seats, ownership and phases. Player movement and six-body jointed ragdolls are simulated by the owning peer for responsiveness.
- One held thing, including another player or clone. Charged throws, punches, impact noise, tomato splats, knockback and ragdoll recovery.
- Preparation **20s**, class **120s**, break **90s**.
- One **Stomach / health** bar. Time and shotgun hits deplete it; food restores it. Eating is a timed exposed action. Low stomach growls, delayed burps and noisy consumables feed the teacher.
- Teacher: away → entering → lecture / warning / checking / investigating / coffee / caught-shot → leaving. Warning precedes normal checks; random checks have a minimum cooldown. Investigation raises future check frequency. Coffee reduces hearing sensitivity. Sleeping tablets increase coffee frequency and duration.
- **Lecturing can catch students:** severe noise or accumulated suspicion can trigger a shot/investigation even with the teacher's back turned. Sound draws attention to its physical origin. A seen violation identifies its actor; otherwise nearby position, suspicious behavior and a small random component choose the culprit. The teacher does not magically know an unseen thrower's identity.
- Ten simple NPC clones; weighted, grade-gated classroom loot; sixteen seats. Players can evict seated NPCs. Out-of-seat / eating / recent stealing or throwing can be seen during checks.
- Allowance is ₿5 attendance + half the food value eaten during class, rounded down. Death waits until the class ends. Re-cloning costs ₿10; a negative balance is debt, **not** elimination. All humans dead simultaneously ends the run. New run resets progression.
- Endless shared score: classes survived. Increasing grades unlock stock and raise hunger/check pressure. The assembled rocket on the lunar surface is a visual preview.
- Physical vending purchases with keypad codes. Seventeen resource-defined items, including the requested foods, energy drink, drugs, cushion, weapons, mystery box, firework and rocket part.
- Menu, LAN code, skippable opening crawl, HUD, scoreboard, pause/quit and restart. Late join during class spectates until the next bell.
- Human art/audio replacement hooks; silent missing audio. Geometry is a replaceable greybox. Roulette/gambling table remains stretch scope.

## Ownership and files

| Dev | Area | Files |
|---|---|---|
| 1 | Network, connection UX, robustness | `autoload/net.gd`, snapshot/RPC section in `autoload/game.gd`, `tests/` |
| 2 | Player feel, carrying, character art, ragdoll tuning | `characters/player/network_player.{tscn,gd}`, `characters/player/ragdoll.{tscn,gd}`, `characters/shared/student_visual.tscn` |
| 3 | Teacher timing, readability, blame and sound | `characters/teacher/teacher.{tscn,gd}`, `autoload/noise_bus.gd`, `autoload/sfx.gd` |
| 4 | Items, economy, vending | `items/`, interaction/economy helpers in `world/classroom/classroom.gd` |
| 5 | Room art, HUD/menus, round playtests | `world/classroom/classroom.tscn`, `world/classroom/props/`, `ui/game_ui.{tscn,gd}`, `config/`, `assets/` |

`world/classroom/classroom.gd` and `autoload/game.gd` are integration points: coordinate edits with their owners. The original player and test scenes live in `prototypes/`. Standalone snippets are in repository-level `reference/snippets/`.

## Godot project folders

Paths here are relative to [the Godot project](../cssa-game-jam/).

| Folder | Contents |
|---|---|
| [main/](../cssa-game-jam/main/) | Entry scene and command-line startup |
| [autoload/](../cssa-game-jam/autoload/), [config/](../cssa-game-jam/config/) | Global services and tuning resources |
| [characters/](../cssa-game-jam/characters/) | Network player, ragdoll, clones, teacher state machine and shared student visual |
| [world/classroom/](../cssa-game-jam/world/classroom/), [world/lunar/](../cssa-game-jam/world/lunar/) | Classroom and hallway props, lunar surface, space backdrop and rocket launch site |
| [items/](../cssa-game-jam/items/), [assets/](../cssa-game-jam/assets/) | Item prefabs and balance data, imported item models, event audio and branding |
| [core/](../cssa-game-jam/core/), [effects/](../cssa-game-jam/effects/) | Interaction primitives, state machine types, audio emitters and visual effects |
| [ui/](../cssa-game-jam/ui/), [tests/](../cssa-game-jam/tests/) | Menus and HUD, smoke and network scenarios |

## Game tuning

Open the relevant `.tres` file in the Godot Inspector.

| File | Settings |
|---|---|
| [game_config.tres](../cssa-game-jam/config/game_config.tres) | Round timers, lobby size, stomach and gas, Bitcoin, cloning, loot and HUD feedback |
| [player_config.tres](../cssa-game-jam/config/player_config.tres) | Walk, sprint, jump, look sensitivity, reach, throw charge, struggle and ragdoll recovery |
| [teacher_config.tres](../cssa-game-jam/config/teacher_config.tres) | Check and warning timing, hearing, suspicion, blame, coffee, movement and shotgun |
| [interactions_config.tres](../cssa-game-jam/config/interactions_config.tres) | Eating and action cooldowns, throws and impacts, weapons, props and vending reach |
| [audio_config.tres](../cssa-game-jam/config/audio_config.tres) | Event folders and clip overrides, playback mix, classroom ambience and lecture chalk |
| [network_config.tres](../cssa-game-jam/config/network_config.tres) | Gameplay and discovery ports, discovery scan and retry timing |
| [items/data/](../cssa-game-jam/items/data/) | Per-item price, grade, spawn weight, mass, food, and noise |

Use the same gameplay, item and network resources on every LAN peer. The
`--prep=`, `--class=`, `--break=`, and `--port=` launch flags override the
local settings for that session. Edit key and mouse bindings under **Project
Settings → Input Map**. The in-game control labels show the default bindings.

Sound events use a matching folder under `event_root` by default. Add an
`event_folders` entry to redirect an event or use `event_streams` to pick an
exact clip or an AudioStreamRandomizer. An empty folder override silences the
event. Hearing and gameplay loudness are tuned in the gameplay resources above.

## Networking contract

- All RPCs live at `/root/Game`; scene creation is driven by stable entity IDs in snapshots. No dependency on peer-local node instance IDs.
- Reliable channel 0: requests, presentation events, registration/initial snapshot. Host validates ownership, alive state, distance, phase, prices, grade and cooldowns before applying actions.
- Unreliable ordered channel 1: 15Hz compressed complete snapshots, chunked into <=1,000-byte payloads. Apply only a complete matching sequence. A lost chunk is repaired by a later full snapshot; no partial world is applied.
- Unreliable ordered channel 2: owner pose updates at about 30Hz. State epochs reject old movement packets after teleports, seating, carrying, ragdoll launches and respawns.
- Host simulated `RigidBody3D` items; clients use frozen bodies and interpolate. Held objects are positioned locally from the holder's pose to avoid round-trip hand lag.
- Friend ragdolls: six `RigidBody3D` boxes with five `PinJoint3D`s. Owner reports limb transforms, peers interpolate visual bodies. Corpses and clone NPCs are throwable single rigid bodies in the greybox.
- This is a trusted-LAN jam implementation, not an anti-cheat design. Host departure ends the session; there is no host migration.

## Shared APIs

- `Game.request(action, data)` — local player requests an authoritative action.
- `NoiseBus.emit_noise(position, loudness, source_id, sound_key)` — **host only**. Physical sound location drives blame. Teacher's own sounds use `Game.event("sound", …)` directly so it doesn't hear itself.
- `Game.world.spawn_item(item_id, position)` — **host only**. Returns a `ClassroomItem`.
- `Game.damage(peer_id, amount, reason, impulse)` — host damage and optional ragdoll.
- `Game.launch_player(peer_id, velocity)` — host orders physical tumble.
- `Game.event.rpc(kind, data)` — reliable visual/audio/UI event; game state belongs in snapshots.
- Item additions: duplicate a resource in `items/data/` and an inherited throwable scene in `items/scenes/`. Set a unique `id`, price/rarity/grade/effect, and assign the complete scene to the resource's `scene` field. Set that scene's `item_id` to match. ItemDB discovers `.tres` resources through Godot's resource-aware listing, including exported builds. Add a `vending_entry.tscn` instance under `VendingRows` in the UI scene and set its `item_id` to expose a new button; keypad codes follow the sorted stock.

## Level editing

Open `world/classroom/classroom.tscn`: the room, sixteen desk instances, teacher, hallway props, environment, lights and camera already exist in the **Scene dock** and 3D viewport. Open an instanced scene with its scene icon, or enable **Editable Children** for per-instance overrides.

- `world/classroom/props/desk.tscn`: desk/chair meshes, colliders, seat interaction, `SitPoint`, two `LootSpawns`, and a `NavigationObstacle` marker. Moving a desk moves all its gameplay markers. The world reads those marker transforms at startup, so layouts no longer need coordinates edited in GDScript.
- `TeacherDesk`, `VendingMachine`, and `TransferChute` are reusable scenes with their interaction volumes and spawn/dispense markers visible in the editor. The outdoor rocket and stand are in `world/lunar/launch_site/lunar_launch_site.tscn`.
- `TeacherWaypoints` contains the board/lounge positions; `Room` contains open/closed door markers.
- The Moon's walkable cap uses a heightmap baked from the visible mesh. To rebuild it after replacing the lunar model or changing the cap, run `python3 cssa-game-jam/tools/bake_lunar_collision.py` from the repository root. The collider and its boundaries are in `world/lunar/planet_surface.tscn`. Floor snap is tuned in `config/player_config.tres`.
- Grid-pathfinding builds its data from the furniture's `NavigationObstacle` markers. Their Inspector `half_extents` include teacher clearance around each desk.
- Room visuals use **The Last Class - School Kit** (`assets/models/school_kit/`). Kit meshes are visual only: walls/floor collision stays on the greybox `StaticBox` nodes (their meshes are hidden) and the kit walls/floors live under `Room/Finish`. Wall modules are `props/school_wall.tscn`, painted by `world/classroom/materials/school_wall.{gdshader,tres}`.
- Solid dressing (`bookcase_*`, `tv_cart`, `locker_bank` in `world/classroom/props/`) goes under the classroom's `Decor` node; `classroom.gd` adds each child's `NavigationObstacle` to the teacher grid. Hallway lockers sit outside the grid.
- Kit `.glb` files import through `assets/models/school_kit/merge_static_meshes.gd`, which merges each model to one mesh with one surface per texture (a 79-piece teacher desk becomes 3 draw calls). New kit models should use the same import script, VRAM-compressed textures capped at 1024 px, and `animation/import=false`.
- `ui/game_ui.tscn` contains the menu, HUD, pause, vending entries and crawl. Layout is defined by anchors/containers; button connections are saved in the scene. Labels, theme and positions can be edited without changing code.
- `characters/player/ragdoll.tscn` contains six rigid bodies and five joints, pre-instanced under every network player. The script activates/resets them rather than constructing bodies. Its root is top-level so the player controller can follow the simulated body without moving it.
- Dynamic players, items, NPCs, sound emitters and effect bursts instantiate their complete `.tscn` prefabs. Gameplay scripts update state and reference existing children using `$`/`%`/`@onready`; they do not construct node hierarchies.

Layers: **1 world, 2 players, 4 objects, 8 teacher/NPCs, 16 interactables** (bit values). Player movement collides with world geometry; host object physics detects player bodies. Seats are explicit interactions, not automatic collision triggers.

## Verification

The Python runners use `godot` from PATH or the executable set in `GODOT_BIN`.

```sh
godot --headless --path cssa-game-jam --editor --import --quit
python3 cssa-game-jam/tests/run_smoke.py
python3 cssa-game-jam/tests/run_network.py
```

The smoke script launches a real ENet host/client pair and exercises registration, replicated objects, contested pickup, charged throwing, friend carry/ragdoll/recovery, vending, grade locks, coffee drugs, eating/allowance, lecture noise response, check cooldown, death, cloning fee, grade progression, wipe and restart. It fails on engine errors/warnings as well as assertions. `--render` renders the host and saves `cosmic-detention.png` in the system temporary directory.

The network test launches six actual Godot processes, checks automatic phase timers, a mid-class spectator joining and re-cloning, teacher sightline occlusion and shotgun damage, replicated large snapshots, graceful peer departure, and host-disconnect cleanup.

Quick manual round:

```sh
godot --path cssa-game-jam -- --host --skip-intro --prep=15 --class=60 --break=20
godot --path cssa-game-jam -- --join=127.0.0.1 --skip-intro
```

Still perform a human two-machine LAN test, then a full six-player comedy/balance playtest before the jam demo. Verify seat reach, teacher sightlines, audio cues, the code for the correct adapter, throwing reactions and the actual exported build on the demo machines.
