## درباره
extends Screen

func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_about")
	box.add_child(UIKit.make_label("دو آسمان (Two Skies)", 12))
	box.add_child(UIKit.make_label("نسخهٔ ۱ — فصل ۱، مرحله‌های ۱ تا ۳", 10, UIKit.MUTED))
	box.add_child(UIKit.make_spacer(6))
	box.add_child(UIKit.make_label("پروفایل اعداد: %s" % KairoConst.active_profile, 9, UIKit.MUTED))
	add_back_button(box)
	return box
