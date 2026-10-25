# Title image

Generated with the built-in imagegen tool on 26 October 2026. The Alchemy Tower
example supplied by the owner informed the level of painterly detail; each scene
was composed for this game's setting and live menu. Text remains native Godot UI.

Asset: `assets/art/ui/title_screen.png`. Original artwork remains preserved.

## Generation prompt

Use case: stylized-concept. Create a polished hand-painted game title background for Auto-Resolved, landscape 16:9, 1920x1080. Rich detailed illustrated indie game key art, warm cinematic lighting and believable materials, comparable craft to a premium fantasy title painting but modern workplace dry comedy. Side-on cutaway of a busy three-floor office at dusk, connected by a clearly visible elevator shaft, workers with different appearances, a paper-jammed printer spilling sheets, server racks with amber warning lights, desks and cables. Foreground at right a tired junior IT worker carrying a laptop, on its screen a small cheerful abstract cyan AI face (PATCH), no humanoid robots. Main visual storytelling on right two thirds, left third subdued dark navy office wall and shadowed desks providing quiet negative space for live game title and menu. Warm windows against cool blue city evening. Inviting comic tension, no catastrophe or weapons. No text, letters, logos, UI, watermark, frames or borders. Save the generated image as a local file and return its path.

## Integration and verification

- The title uses this project-local image with aspect-preserving cover scaling.
- Text, focus, settings, saves and start actions remain native Godot UI.
- Godot 4.7.2 headless editor import completed successfully.
- Silent automated windowed capture ran on the OpenGL Compatibility renderer;
  the rendered title was visually inspected at one fixed size.
- Capture: `docs/verification/career_title.png`. Reproduce with
  `Godot --path . --audio-driver Dummy --script res://tools/capture_title.gd`.
- No gameplay simulation suite, export, browser/touch pass or human playtest
  was run for this title-art change. Nothing was pushed or published.
