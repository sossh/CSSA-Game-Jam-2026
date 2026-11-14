LOBBY BLOOPER TV  (drop files here)

The TV on the lobby's back wall plays everything in this folder, in
alphabetical order, forever. No code changes, no Godot import step.
Add or remove files while the game is running; the TV notices on its next clip.

Images : .png .jpg .jpeg .webp .bmp .tga   (shown ~6 s, downscaled automatically)
Video  : .ogv only (Ogg Theora, the only video format Godot can play)

The filename becomes the on-screen caption, so name files like:
    01_teacher_fell_asleep.jpg   ->  TEACHER FELL ASLEEP
Leading numbers, dashes and underscores are dropped, so use them to set the order.

Convert other video (mp4, mov) to .ogv, 480p to 720p is plenty:
    ffmpeg -i clip.mp4 -vf scale=-2:480 -c:v libtheora -q:v 6 -an 05_clip.ogv

Only content the team made or is licensed to use. No AI-generated art.

Exported builds: copy this whole folder next to the game executable
(next to the .app on macOS), or into the .app's Contents/Resources.
Tuning (seconds per image, max video length) is on the WallTV node in
world/classroom/props/wall_tv.tscn.
