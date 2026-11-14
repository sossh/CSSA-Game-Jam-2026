# Audio event folders

Add human-recorded or licensed `.ogg`/`.wav` files under event folders, e.g.
`chew/chew_01.ogg`, `teacher_warning/throat_clear.wav`, `shotgun/blast.ogg`.
`autoload/sfx.gd` discovers variations automatically. Missing folders are silent.

Open [audio_config.tres](../../config/audio_config.tres) in the Godot Inspector
to change the event root, point individual events to another folder, or assign a
specific clip or AudioStreamRandomizer. Classroom ambience, lecture chalk, and
playback levels are also in that resource.

See `../../../docs/ASSETS.md` for the prioritized list and record credits in
`../../../used-assets.txt`. No AI-generated sound assets.
