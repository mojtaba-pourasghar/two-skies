## اسپلش — docs/02_godot_spec.md §۱۳
extends Screen

func build() -> VBoxContainer:
	var box := UIKit.make_root("")
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(UIKit.make_label("دو آسمان", 20))
	box.add_child(UIKit.make_label("Two Skies", 10, UIKit.MUTED))
	return box

func _ready() -> void:
	super()
	await Wait.seconds(self, 1.2)
	SceneRouter.goto("main_menu", false)
