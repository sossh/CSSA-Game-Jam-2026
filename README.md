# Cosmic Detention — CSSA Game Jam 2026

First-person LAN co-op classroom chaos for 2–6 players. Abducted humans must eat
through alien class without attracting their shotgun-wielding teacher. Throw
snacks and friends, survive, spend Bitcoin, and add to the shared escape rocket.

## Play

1. Open `cssa-game-jam/project.godot` with Godot **4.7.x**, wait for the editor
   to finish importing assets, and press **F5**. For a terminal launch from the
   repository root, run `python3 cssa-game-jam/run_game.py` (use `py` on Windows).
   The launcher imports new and changed assets before starting the game. It uses
   `godot` from your PATH, or the executable set in `GODOT_BIN`.
2. One player selects **Host Classroom**. Friends select **Find LAN Games**, choose the host, and select **Join LAN Game**. They can also enter the host's Wi-Fi IP or join code.
3. Skip the intro; host presses **Enter** to start. Default rounds: 20s preparation,
   5min class, 90s break. See the [tuning guide](docs/DEVELOPMENT.md#game-tuning) for gameplay, audio, and LAN settings.

**WASD** move, **mouse** look, **E** grab/sit/interact, **hold/release LMB** throw,
**LMB empty-handed** punch, **RMB** eat/use, **Q** drop, **Space** jump/stand/escape,
**Shift** sprint, **F** fart, **Tab** register, **Esc** menu.

- [Prioritized 3D, sound, and miscellaneous asset lists](docs/ASSETS.md)
- [Five-dev handoff, architecture, controls, and tests](docs/DEVELOPMENT.md)

## Repository layout

| Folder | Contents |
|---|---|
| [cssa-game-jam/](cssa-game-jam/) | Godot project, playable scenes, runtime assets and tests |
| [art-source/](art-source/) | Source models, Blockbench projects and original audio |
| [reference/snippets/](reference/snippets/) | Earlier code and asset experiments |
| [docs/](docs/) | Development handoff and asset integration guide |

Edit the level in `cssa-game-jam/world/classroom/classroom.tscn` and menus/HUD in
`cssa-game-jam/ui/game_ui.tscn`. Players, ragdolls, teacher, props and all items
have editable scene trees; gameplay scripts reference those existing nodes.

Greybox models and visual cues are included. Human-made/licensed audio and art
are ready to integrate; missing audio is silent. No microphone/proximity chat.

```sh
python3 cssa-game-jam/tests/run_smoke.py
```
