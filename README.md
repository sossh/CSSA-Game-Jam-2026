# Cosmic Detention — CSSA Game Jam 2026

First-person LAN co-op classroom chaos for 2–6 players. Abducted humans must eat
through alien class without attracting their shotgun-wielding teacher. Throw
snacks and friends, survive, spend Bitcoin, and add to the shared escape rocket.

## Play

1. Open `cssa-game-jam/project.godot` with Godot **4.7.x** and press **F5**.
2. One player hosts. Friends on the same LAN enter the displayed join code.
3. Skip the intro; host presses **Enter** to start. Default rounds: 30s preparation,
   5min class, 90s break. Edit `cssa-game-jam/config/game_config.tres` to tune.

**WASD** move, **mouse** look, **E** grab/sit/interact, **hold/release LMB** throw,
**LMB empty-handed** punch, **RMB** eat/use, **Q** drop, **Space** jump/stand/escape,
**Shift** sprint, **G** fart, **Tab** register, **Esc** menu.

- [Prioritized 3D, sound, and miscellaneous asset lists](docs/ASSETS.md)
- [Five-dev handoff, architecture, controls, and tests](docs/DEVELOPMENT.md)

Edit the level in `cssa-game-jam/world/classroom.tscn` and menus/HUD in
`cssa-game-jam/ui/game_ui.tscn`. Players, ragdolls, teacher, props and all items
have editable scene trees; gameplay scripts reference those existing nodes.

Greybox models and visual cues are included. Human-made/licensed audio and art
are ready to integrate; missing audio is silent. No microphone/proximity chat.

```sh
python3 cssa-game-jam/tests/run_smoke.py
```
