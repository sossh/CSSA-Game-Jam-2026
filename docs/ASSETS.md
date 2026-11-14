# Human asset collection — priority order

The current build uses primitive greybox geometry and **no generated audio or finished art**. Record, model, draw, or source these yourselves. Add the creator, source URL, license, attribution and destination to `used-assets.txt` as you integrate each asset.

## 3D models

| Priority | Collect | Minimum useful delivery |
|---|---|---|
| 1 | **Student / player** | One readable, funny human; reuse for all ten clone NPCs. Colorable clothing. Idle, walk, sit, eat, held/flail poses. A simple six-part body or humanoid rig makes ragdoll replacement straightforward. Existing character template is a starting point. |
| 2 | **Alien teacher + shotgun + coffee mug** | Very obvious front/back silhouette. Chalk-writing, warning/turn, scan, walk, aim, shoot/pump, yawn/sip. These sell the central joke. |
| 3 | **Desk and chair** | One set, instantiated sixteen times. Keep the desk top near 0.87 m and a seated eye near 1.15 m. Separate chair/desk meshes. |
| 4 | **Core food props** | Tomato, chip bag, apple, white energy-drink can, chocolate, carrot, nearly empty Slurpee. Start with tomato/chips/can: they anchor the demo. |
| 5 | **Vending machine** | Front keypad, readable product window, purchase chute and floor tray. It must visibly dispense physical items. |
| 6 | **Classroom shell** | Sci-fi floor/wall/ceiling modules, doorway/door, board, giant clock, lights, teacher desk. Existing Molten Maps pack is a candidate. |
| 7 | **Transfer chute and hallway** | Tube, landing zone, classroom signage, cloning station dressing. |
| 8 | **Sleeping tablets + whoopee cushion** | Distinct silhouettes so players identify them immediately. |
| 9 | **Rocket parts + build pad** | Three or four reusable chunks and a recognizable assembled silhouette. The assembled rocket preview is on the lunar surface. |
| 10 | **Later-grade items** | Toy/nerf gun, player gun, karambit, firework, mystery box, Pop Rocks packet, moon rock. |
| 11 | **Classroom dressing** | Backpacks (loot spots), posters, notebooks, meter stick, laptop/monitor. |
| 12 | **Stretch-only gambling assets** | Roulette table, chips, wheel, gambling-kid variant. Roulette is not in the playable core. |

### Model handoff

Repository-level [art-source/](../art-source/) holds original models, Blockbench projects and audio. Place assets prepared for import in the Godot project with the scenes that use them.

- Prefer `.glb`, meters, Y up, character forward **-Z**, applied transforms. Character origin at feet; item origins at their center of mass.
- Keep visual meshes separate from gameplay colliders and interaction markers. Low-poly, strong silhouette beats detail at this scale.
- Item models go into `cssa-game-jam/assets/models/items/`. Open the corresponding `items/scenes/*.tscn`, hide/replace its `Visual` mesh, and instance the imported model there. Adjust its collider in the same scene. The resource's `scene` field references the complete throwable scene.
- Characters share `characters/shared/student_visual.tscn`; edit `characters/player/network_player.tscn`, `characters/player/ragdoll.tscn`, `characters/npc/kid.tscn` and `characters/teacher/teacher.tscn` for their bodies, cameras, joints and props. Room geometry and lighting live in `world/classroom/classroom.tscn` with reusable furniture in `world/classroom/props/`.

## Sounds

**First recording session:** grab a mic, a snack bag, a drink can and something squishy. Multiple human variations are more valuable than pristine audio.

| Priority | Sound | Runtime event folder(s) |
|---|---|---|
| 1 | **Teacher warning** — chalk stops, throat-clear, hostile inhale | `teacher_warning/` |
| 2 | **Obnoxious chewing / chip crunching** — 4–8 short takes | `chew/`, `crunch/` |
| 3 | **Shotgun pump and blast** — separate, punchy recordings | `shotgun_pump/`, `shotgun/` |
| 4 | **Burps, farts, sneezes, stomach growls** — several variants | `burp/`, `fart/`, `sneeze/`, `stomach_growl/` |
| 5 | **Teacher coffee slurp and yawn** — obvious snack-window cue | `coffee/`, `teacher_yawn/` |
| 6 | **Tomato splat, body/item impacts, punch** | `splat/`, `impact/`, `punch/` |
| 7 | **School bell** — recognizable start/end punctuation | `bell/` |
| 8 | **Can crack, almost-empty slurp, Pop Rocks** | `can_open/`, `slurp/`, `pop_rocks/` |
| 9 | **Footsteps, grabs, throwing whoosh** | `footstep/`, `pickup/`, `throw/` |
| 10 | **Vending mechanism and tray clunk** | `vending_dispense/` |
| 11 | **Lecture gibberish / chalk-writing snippets** | `lecture/` |
| 12 | **Player gun / firework** | `gunshot/`, `firework/` |
| 13 | **Chute slide, cloning zap, death reaction, door mechanism** | Future polish hooks: `chute/`, `clone/`, `death/`, `door/` |
| 14 | **Menu / crawl music, classroom ambience, victory/failure stings** | Future music/ambience bus integration |

### Sound handoff

- Put mono positional `.ogg` or `.wav` files in `cssa-game-jam/assets/audio/<event>/`, e.g. `chew/chew_01.ogg`. The loader discovers variations after importing and restarting. Set per-event replacements, the ambience track, and the chalk track in [audio_config.tres](../cssa-game-jam/config/audio_config.tres).
- Trim accidental silence, avoid clipping, leave headroom. 44.1/48 kHz mono is fine; stereo is useful for future music.
- Missing files are silent. Visual warning text and teacher labels currently communicate the important cues.
- The host's `NoiseBus` decides gameplay loudness independently of audio volume. Quieting the audio mix does not make the player stealthier.
- No proximity voice chat or microphone capture is included.

## Miscellaneous

1. **Title/logo and readable font:** title, menu, money/stomach icons; `.ttf`/`.otf` with redistribution permission.
2. **Character colors and name readability:** six distinct outfits/palettes; NPC clones visually distinct from friends.
3. **Board/poster/sign textures:** alien nonsense lessons, vending labels/prices, cloning receipt, classroom rules. Best opportunity for human-written jokes.
4. **Space backdrop:** hand-made or licensed starfield/planet/window textures to make the Cosmos setting obvious.
5. **VFX textures:** tomato smear, crumbs, muzzle flash, smoke, impact dust. Current effects are simple geometry.
6. **UI polish:** item icons, timer treatment, damage vignette, skippable intro styling, end-of-run scoreboard.
7. **Credits and attribution file:** authors, exact licenses, source links, required credit text. Preserve the existing asset sources.
8. **Demo material:** two-minute scenario, six-machine LAN check, title screenshot, controls card, export icon.

## Fastest demo asset bundle

**Student + teacher + shotgun + desk/chair + tomato + chips + white can + vending machine**, accompanied by **warning, crunch, splat, pump/blast, burp, coffee and bell**. Integrate that set before collecting decorative assets.
