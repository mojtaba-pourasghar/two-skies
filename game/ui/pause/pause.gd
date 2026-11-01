## صفحهٔ مکث — docs/02_godot_spec.md §۱۳
extends Screen

func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_pause")
	var resume := UIKit.make_button("ui_resume")
	resume.pressed.connect(func():
		get_tree().paused = false
		queue_free())
	box.add_child(resume)
	var restart := UIKit.make_button("ui_restart")
	restart.pressed.connect(func():
		get_tree().paused = false
		SceneRouter.goto("game", false))
	box.add_child(restart)
	var quit := UIKit.make_button("ui_quit_level")
	quit.pressed.connect(func():
		get_tree().paused = false
		SceneRouter.goto("world_map", false))
	box.add_child(quit)
	return box
