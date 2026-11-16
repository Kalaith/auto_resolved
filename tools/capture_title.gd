extends "res://addons/hatchery/testing/title_capture.gd"
## Focused, silent windowed capture of the real startup screen (the toolkit's
## title capture).
## Run with --audio-driver Dummy --script res://tools/capture_title.gd.


func window_size() -> Vector2i:
	return Vector2i(1280, 720)


func label() -> String:
	return "career_title"
